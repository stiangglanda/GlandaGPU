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

    signal tb_bus_addr   : std_logic_vector(31 downto 0);
    signal tb_bus_we     : std_logic;
    signal tb_bus_din    : std_logic_vector(31 downto 0);
    signal tb_bus_dout   : std_logic_vector(31 downto 0);
    signal tb_bus_wait   : std_logic;

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
            bus_addr => tb_bus_addr,
            bus_we => tb_bus_we,
            bus_din => tb_bus_din,
            bus_dout => tb_bus_dout,
            bus_wait => tb_bus_wait,
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
            -- Add 0x200000 (Bit 21) for Register Access, Shift index to byte address
            tb_bus_addr <= std_logic_vector(shift_left(to_unsigned(addr, 32), 2) or x"00200000"); 
            tb_bus_din  <= data;
            tb_bus_we   <= '1';
            wait until rising_edge(clk);
            tb_bus_we   <= '0';
            tb_bus_din  <= (others => '0');
        end procedure;

        procedure cpu_write_and_start(addr : in integer; data : in std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
             -- Add 0x200000 (Bit 21) for Register Access
            tb_bus_addr <= std_logic_vector(shift_left(to_unsigned(addr, 32), 2) or x"00200000");
            tb_bus_din  <= data;
            tb_bus_we   <= '1';
            wait until rising_edge(clk);
            tb_bus_we   <= '0';
        
            -- shouldent be necessary anymore, but just to be safe
            for i in 1 to 5 loop
                wait until rising_edge(clk);
            end loop;
            
            loop
                tb_bus_addr <= x"00200000"; -- Status Rigster + Offset
                wait until rising_edge(clk);
                exit when tb_bus_dout(0) = '0';
            end loop;
        end procedure;

        -- Wait until Busy=0
        procedure wait_gpu_ready is
        begin
            loop
                tb_bus_addr <= x"00200000"; 
                wait until rising_edge(clk);
                -- Bit 0(Busy)
                exit when tb_bus_dout(0) = '0';
            end loop;
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
                tb_bus_addr <= x"00200014"; -- ISR Address + Offset (Reg 5 * 4 = 20 = 0x14)
                tb_bus_we   <= '0';
                
                wait until rising_edge(clk);
                wait for 1 ns;
                
                isr_val := tb_bus_dout;
                
                if unsigned(isr_val) /= 0 then
                    exit;
                end if;
            end loop;

            report "Interrupt received. ISR Value: " & integer'image(to_integer(unsigned(isr_val)));

            -- W1C to acknwoledge the interrupt
            wait until rising_edge(clk);
            tb_bus_we   <= '1';
            tb_bus_din  <= isr_val;
            
            wait until rising_edge(clk);
            tb_bus_we   <= '0';
            tb_bus_din  <= (others => '0');
            
            wait until tb_irq = '0';
        end procedure;

        procedure vram_write(offset : in integer; color : in std_logic_vector(11 downto 0)) is
        begin
            wait until rising_edge(clk);
            tb_bus_addr <= std_logic_vector(to_unsigned(offset, 32)); -- Direct VRAM mapping
            tb_bus_din  <= x"00000" & color;
            tb_bus_we   <= '1';
            
            loop
                wait until rising_edge(clk);
                exit when tb_bus_wait = '0'; 
            end loop;

            tb_bus_we   <= '0';
            tb_bus_din  <= (others => '0');
        end procedure;

        procedure vram_check(offset : in integer; expected : in std_logic_vector(11 downto 0)) is
            variable read_val : std_logic_vector(31 downto 0);
        begin
            wait until rising_edge(clk);
            tb_bus_addr <= std_logic_vector(to_unsigned(offset, 32));
            tb_bus_we   <= '0';
            
            loop
                wait until rising_edge(clk);
                exit when tb_bus_wait = '0';
            end loop;
            
            wait until rising_edge(clk); 
            read_val := tb_bus_dout;
            
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
        -- Red Pixel at (0,0) -> Offset 0
        vram_write(0, x"F00");
        -- Green Pixel at (1,0) -> Offset 4
        vram_write(4, x"0F0");
        -- Blue Pixel at (2,0) -> Offset 8
        vram_write(8, x"00F");
        
        -- Read Back
        vram_check(0, x"F00");
        vram_check(4, x"0F0");
        vram_check(8, x"00F");
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