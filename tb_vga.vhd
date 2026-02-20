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

    signal tb_reg_cmd      :  std_logic_vector(3 downto 0); -- 1=Clear, 2=Rect, 3=Line
    signal tb_reg_x, tb_reg_y, tb_reg_w, tb_reg_h : unsigned(9 downto 0) := (others => '0');
    signal tb_reg_color : std_logic_vector(11 downto 0) := (others => '0');
    signal tb_reg_start : std_logic := '0';
    signal tb_gpu_busy  : std_logic;
    
    -- Simulation Control
    constant CLK_PERIOD : time := 40 ns; -- 25 MHz
    signal sim_running  : boolean := true;
begin

    -- Instantiate VGA Controller
    uut: entity work.top_gpu
        port map (
            clk   => clk,
            reset   => reset,
            reg_cmd => tb_reg_cmd,
            reg_x => tb_reg_x,
            reg_y => tb_reg_y,
            reg_w => tb_reg_w,
            reg_h => tb_reg_h,
            reg_color => tb_reg_color,
            reg_start => tb_reg_start,
            gpu_busy  => tb_gpu_busy,
            hsync => hsync,
            vsync => vsync,
            video_on => video_on,
            red   => red,
            green => green,
            blue  => blue
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
    begin
        -- Reset
        reset <= '1';
        tb_reg_start <= '0';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;
        wait until rising_edge(clk);

        -- clear screen
        tb_reg_cmd   <= x"1";
        tb_reg_color <= x"030"; -- Dark Green
        tb_reg_start <= '1';
        wait until rising_edge(clk);
        tb_reg_start <= '0';
        
        -- wait until busy, then until done
        wait until tb_gpu_busy = '1';
        wait until tb_gpu_busy = '0';
        
        report "Clear Screen finished";
        wait for 1 us;

        -- Draw red rectangle
        tb_reg_cmd   <= x"2";
        tb_reg_x     <= to_unsigned(100, 10);
        tb_reg_y     <= to_unsigned(100, 10);
        tb_reg_w     <= to_unsigned(50, 10);
        tb_reg_h     <= to_unsigned(50, 10);
        tb_reg_color <= x"F00"; -- red
        
        wait until rising_edge(clk);
        tb_reg_start <= '1';
        wait until rising_edge(clk);
        tb_reg_start <= '0';

        -- wait until busy, then until done
        wait until tb_gpu_busy = '1';
        wait until tb_gpu_busy = '0';
        
        report "Red Rectangle finished";

        -- Draw line
        tb_reg_cmd   <= x"3"; -- DRAW_LINE
        tb_reg_x     <= to_unsigned(10, 10);  -- X0
        tb_reg_y     <= to_unsigned(10, 10);  -- Y0
        tb_reg_w     <= to_unsigned(600, 10); -- X1
        tb_reg_h     <= to_unsigned(400, 10); -- Y1
        tb_reg_color <= x"FFF"; -- White
        
        wait until rising_edge(clk); 
        tb_reg_start <= '1';
        wait until rising_edge(clk); 
        tb_reg_start <= '0';
        wait until tb_gpu_busy = '1';
        wait until tb_gpu_busy = '0';

        report "first line finished";

        tb_reg_x     <= to_unsigned(300, 10);
        tb_reg_y     <= to_unsigned(10, 10);
        tb_reg_w     <= to_unsigned(350, 10);
        tb_reg_h     <= to_unsigned(450, 10);
        tb_reg_color <= x"0F0"; -- Green

        wait until rising_edge(clk); 
        tb_reg_start <= '1';
        wait until rising_edge(clk); 
        tb_reg_start <= '0';
        wait until tb_gpu_busy = '1';
        wait until tb_gpu_busy = '0';

        report "second line finished";

        wait until falling_edge(vsync);
        wait until falling_edge(vsync);
        
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