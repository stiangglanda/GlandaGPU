library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_gpu is
    Port ( 
        clk   : in std_logic;
        reset : in std_logic;
        hsync : out std_logic;
        vsync : out std_logic;
        video_on : out std_logic;
        red, green, blue : out std_logic_vector(3 downto 0)
    );
end top_gpu;

architecture Structural of top_gpu is
    signal vram_addr_vga : std_logic_vector(18 downto 0);
    signal vram_data_vga : std_logic_vector(11 downto 0);
    
    signal gpu_we   : std_logic := '0';
    signal gpu_addr : std_logic_vector(18 downto 0) := (others => '0');
    signal gpu_din  : std_logic_vector(11 downto 0) := (others => '0');
begin

    -- VRAM Instanz
    vram_inst : entity work.vram
        port map (
            clk    => clk,
            we_a   => gpu_we,
            addr_a => gpu_addr,
            din_a  => gpu_din,
            addr_b => vram_addr_vga,
            dout_b => vram_data_vga
        );

    -- VGA Controller Instanz
    vga_inst : entity work.vga_controller
        port map (
            clk        => clk,
            reset      => reset,
            pixel_data => vram_data_vga,
            pixel_addr => vram_addr_vga,
            hsync      => hsync,
            vsync      => vsync,
            video_on   => video_on,
            red        => red,
            green      => green,
            blue       => blue
        );

    -- Initialise VRAM with white
    process(clk)
        variable count : integer := 0;
    begin
        if rising_edge(clk) then
            if count < 307200 then -- 640x480 = 307200 Pixel
                gpu_we   <= '1';
                gpu_addr <= std_logic_vector(to_unsigned(count, 19));
                gpu_din  <= x"FFF"; 
                count := count + 1;
            else
                gpu_we <= '0';
            end if;
        end if;
    end process;

end Structural;