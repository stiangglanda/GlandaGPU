library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL; -- for File I/O

entity tb_vga is
end tb_vga;

architecture sim of tb_vga is
    signal clk     : std_logic := '0';
	signal reset   : std_logic := '0';
    signal hsync   : std_logic;
    signal vsync   : std_logic;
	signal video_on: std_logic;
    signal red     : std_logic_vector(3 downto 0);
    signal green   : std_logic_vector(3 downto 0);
    signal blue    : std_logic_vector(3 downto 0);

    signal tb_avs_address   : std_logic_vector(21 downto 0);
    signal tb_avs_write     : std_logic;
    signal tb_avs_writedata    : std_logic_vector(31 downto 0);
    signal tb_avs_read      : std_logic := '0';
    signal tb_avs_readdata   : std_logic_vector(31 downto 0);
    signal tb_avs_waitrequest   : std_logic;

    signal tb_irq : std_logic;
    
    -- Simulation Control
    constant CLK_PERIOD : time := 40 ns; -- 25 MHz
    signal sim_running  : boolean := true;
begin

    -- Instantiate GPU
    uut: entity work.top_gpu
        port map (
            clk   => clk,
            reset   => reset,
            avs_address => tb_avs_address,
            avs_write => tb_avs_write,
            avs_writedata => tb_avs_writedata,
            avs_read => tb_avs_read,
            avs_readdata => tb_avs_readdata,
            avs_waitrequest => tb_avs_waitrequest,
            hsync => hsync,
            vsync => vsync,
            video_on => video_on,
            red   => red,
            green => green,
            blue  => blue,
            irq   => tb_irq
        );

    -- Clock Generation
    clk_process: process
    begin
        while sim_running loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    stimuli: process
        -- Helper functions
        procedure cpu_write(addr : in integer; data : in std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            -- Add Bit 19 for Register Access, map address directly
            tb_avs_address <= std_logic_vector(resize(to_unsigned(addr, 22) or "00" & x"80000", 22)); 
            tb_avs_writedata  <= data;
            tb_avs_write   <= '1';
            wait until rising_edge(clk);
            tb_avs_write   <= '0';
            tb_avs_writedata  <= (others => '0');
        end procedure;

        procedure cpu_write_and_start(addr : in integer; data : in std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
             -- Add Bit 19 for Register Access
            tb_avs_address <= std_logic_vector(resize(to_unsigned(addr, 22) or "00" & x"80000", 22));
            tb_avs_writedata  <= data;
            tb_avs_write   <= '1';
            wait until rising_edge(clk);
            tb_avs_write   <= '0';
        
            -- shouldent be necessary anymore, but just to be safe
            for i in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;
            
            loop
                tb_avs_address <= "00" & x"80000"; -- Status Rigster + Offset
                tb_avs_read <= '1';
                wait until rising_edge(clk);
                exit when tb_avs_readdata(0) = '0';
            end loop;
            tb_avs_read <= '0';
        end procedure;

        -- Wait until Busy=0
        procedure wait_gpu_ready is
        begin
            loop
                tb_avs_address <= "00" & x"80000";
                tb_avs_read <= '1';
                wait until rising_edge(clk);
                -- Bit 0(Busy)
                exit when tb_avs_readdata(0) = '0';
            end loop;
            tb_avs_read <= '0';
        end procedure;

        procedure wait_and_clear_irq is
            variable isr_val : std_logic_vector(31 downto 0);
        begin
            if tb_irq = '1' then
                wait until tb_irq = '0';
            end if;

            wait until tb_irq = '1';
            
            wait for 10 ns; -- wait for vaulues to stabilize

            loop
                wait until rising_edge(clk);
                tb_avs_address <= "00" & x"80005"; -- ISR Address + Offset (Reg 5 = 0x05)
                tb_avs_write   <= '0';
                tb_avs_read    <= '1';
                
                wait until rising_edge(clk);
                wait for 1 ns;
                
                isr_val := tb_avs_readdata;
                
                if unsigned(isr_val) /= 0 then
                    tb_avs_read    <= '0';
                    exit;
                end if;
            end loop;
            tb_avs_read    <= '0';

            report "Interrupt received. ISR Value: " & integer'image(to_integer(unsigned(isr_val)));

            -- W1C to acknwoledge the interrupt
            wait until rising_edge(clk);
            tb_avs_write   <= '1';
            tb_avs_writedata  <= isr_val;
            
            wait until rising_edge(clk);
            tb_avs_write   <= '0';
            tb_avs_writedata  <= (others => '0');
            
            wait until tb_irq = '0';
        end procedure;

        procedure vram_write(offset : in integer; color : in std_logic_vector(11 downto 0)) is
        begin
            wait until rising_edge(clk);
            tb_avs_address <= std_logic_vector(to_unsigned(offset, 22)); -- Direct VRAM mapping
            tb_avs_writedata  <= x"00000" & color;
            tb_avs_write   <= '1';
            
            loop
                wait until rising_edge(clk);
                exit when tb_avs_waitrequest = '0'; 
            end loop;

            tb_avs_write   <= '0';
            tb_avs_writedata  <= (others => '0');
        end procedure;

        procedure vram_check(offset : in integer; expected : in std_logic_vector(11 downto 0)) is
            variable read_val : std_logic_vector(31 downto 0);
        begin
            wait until rising_edge(clk);
            tb_avs_address <= std_logic_vector(to_unsigned(offset, 22));
            tb_avs_write   <= '0';
            tb_avs_read    <= '1';
            
            loop
                wait until rising_edge(clk);
                exit when tb_avs_waitrequest = '0';
            end loop;
            
            wait until rising_edge(clk); 
            read_val := tb_avs_readdata;
            tb_avs_read <= '0';
            
            if read_val(11 downto 0) /= expected then
                report "VRAM Mismatch at " & integer'image(offset) & 
                       ". Expected " & integer'image(to_integer(unsigned(expected))) & 
                       " Got " & integer'image(to_integer(unsigned(read_val(11 downto 0)))) 
                       severity failure;
            else
                report "VRAM Read Match at " & integer'image(offset);
            end if;
        end procedure;
    begin
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;

        report "Starting GPU";

        -- 6 = IER (Interrupt Enable Register) Bit 0 (Done) Bit 1 (VSync) -> 0x03
        cpu_write(6, x"00000003"); 
        report "Interrupts enabled.";

        --- Clear Screen
        cpu_write(4, x"00000008"); -- Dark Blue
        cpu_write(1, x"00000011"); -- CMD 1, Start Bit 4

        wait_and_clear_irq; -- Warten auf Done
        report "Clear Screen Done (via Interrupt)";

        report "Waiting for VSync Interrupt";
        wait_and_clear_irq; -- Warten auf VSync
        report "VSync reached";

        -- Draw Yellow Rectangle
        cpu_write(2, x"00320032"); -- X0=50, Y0=50
        cpu_write(3, x"006400C8"); -- W=200, H=100
        cpu_write(4, x"00000FF0"); -- Yellow
        cpu_write_and_start(1, x"00000012"); -- CMD=1 (Rect), Start=Bit 4 -> 0x12

        wait_and_clear_irq;
        report "Rectangle Done";

        -- Draw white line
        cpu_write(2, x"0190000A"); -- X0=10, Y0=400
        cpu_write(3, x"00320258"); -- X1=600, Y1=50
        cpu_write(4, x"00000FFF"); -- White
        cpu_write_and_start(1, x"00000013"); -- CMD=3 (Line), Start=Bit 4 -> 0x13

        wait_and_clear_irq;
        report "Line Done";

        report "Testing VRAM Access";
        -- Red Pixel at (0,0)
        vram_write(0, x"F00");
        -- Green Pixel at (1,0)
        vram_write(1, x"0F0");
        -- Blue Pixel at (2,0)
        vram_write(2, x"00F");
        
        -- Read Back
        vram_check(0, x"F00");
        vram_check(1, x"0F0");
        vram_check(2, x"00F");
        report "VRAM Access Done";

        wait for 20 ms;
        sim_running <= false;
        wait;
    end process;

    -- Capure VGA Output to PPM File
    file_writer: process
        file outfile  : text open write_mode is "vga_output.ppm";
        variable l    : line;
        variable r_int, g_int, b_int : integer;
    begin
        -- PPM Header
        write(l, string'("P3")); write(l, string'(" "));
        write(l, string'("640")); write(l, string'(" "));
        write(l, string'("480")); write(l, string'(" "));
        write(l, string'("15"));  -- 4-bit color(15)
        writeline(outfile, l);

        -- Wait for the first full frame
        wait until falling_edge(vsync);
        wait until rising_edge(vsync);

        for y in 0 to 479 loop
            for x in 0 to 639 loop
				loop
					wait until rising_edge(clk);
					exit when video_on = '1'; 
				end loop;
                
                r_int := to_integer(unsigned(red));
                g_int := to_integer(unsigned(green));
                b_int := to_integer(unsigned(blue));

                write(l, r_int); write(l, string'(" "));
                write(l, g_int); write(l, string'(" "));
                write(l, b_int); write(l, string'("  "));
            end loop;
            writeline(outfile, l); 
        end loop;

        report "Frame captured to vga_output.ppm";
        wait;
    end process;

end sim;