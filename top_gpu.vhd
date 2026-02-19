library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_gpu is
    Port ( 
        clk   : in std_logic;
        reset : in std_logic;

        -- Register Interface
        reg_cmd   : in  std_logic_vector(3 downto 0); -- 1=Rect, 2=Clear
        reg_x     : in  unsigned(9 downto 0);
        reg_y     : in  unsigned(9 downto 0);
        reg_w     : in  unsigned(9 downto 0);
        reg_h     : in  unsigned(9 downto 0);
        reg_color : in  std_logic_vector(11 downto 0);
        reg_start : in  std_logic;
        gpu_busy  : out std_logic;

        -- VGA Interface
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

    engine_inst : entity work.gpu_engine
        port map (
            clk       => clk,
            reset     => reset,
            reg_cmd   => reg_cmd,
            reg_x     => reg_x,
            reg_y     => reg_y,
            reg_w     => reg_w,
            reg_h     => reg_h,
            reg_color => reg_color,
            reg_start => reg_start,
            busy      => gpu_busy,
            vram_we   => gpu_we,
            vram_addr => gpu_addr,
            vram_din  => gpu_din
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

end Structural;