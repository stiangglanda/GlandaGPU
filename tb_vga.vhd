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
    
    -- Simulation Control
    constant CLK_PERIOD : time := 40 ns; -- 25 MHz
    signal sim_running  : boolean := true;
begin

    -- Instantiate VGA Controller
    uut: entity work.top_gpu
        port map (
            clk   => clk,
            reset   => reset,
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

        sim_running <= false;
        report "Frame captured to vga_output.ppm";
        wait;
    end process;

end sim;