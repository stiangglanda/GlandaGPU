library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_gpu is
    Port ( 
        clk   : in std_logic;
        reset : in std_logic;

        -- Bus Interface
        bus_addr   : in std_logic_vector(3 downto 0);
        bus_we     : in std_logic;
        bus_din    : in std_logic_vector(31 downto 0);
        bus_dout   : out std_logic_vector(31 downto 0);

        -- VGA Interface
        hsync : out std_logic;
        vsync : out std_logic;
        video_on : out std_logic;
        red, green, blue : out std_logic_vector(3 downto 0);

        irq : out std_logic
    );
end top_gpu;

architecture Structural of top_gpu is
    signal vram_addr_vga : std_logic_vector(18 downto 0);
    signal vram_data_vga : std_logic_vector(11 downto 0);
    
    signal gpu_we   : std_logic := '0';
    signal gpu_addr : std_logic_vector(18 downto 0) := (others => '0');
    signal gpu_din  : std_logic_vector(11 downto 0) := (others => '0');

    -- Register Interface
    signal reg_cmd   : std_logic_vector(3 downto 0); -- 1=Clear, 2=Rect, 3=Line
    signal reg_x     : unsigned(9 downto 0);
    signal reg_y     : unsigned(9 downto 0);
    signal reg_w     : unsigned(9 downto 0);
    signal reg_h     : unsigned(9 downto 0);
    signal reg_color : std_logic_vector(11 downto 0);
    signal reg_start : std_logic;
    signal gpu_busy  : std_logic;

    signal vsync_internal : std_logic;
    signal hsync_internal : std_logic;
    signal video_on_internal : std_logic;
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

    -- GPU Register Instanz
    gpu_regs_inst : entity work.gpu_regs
        port map (
            clk       => clk,
            reset     => reset,
            bus_addr  => bus_addr,
            bus_we    => bus_we,
            bus_din   => bus_din,
            bus_dout  => bus_dout,
            gpu_x0    => reg_x,
            gpu_y0    => reg_y,
            gpu_x1    => reg_w,
            gpu_y1    => reg_h,
            gpu_color  => reg_color,
            gpu_cmd    => reg_cmd,
            gpu_start  => reg_start,
            gpu_busy   => gpu_busy,
            vga_vsync  => vsync_internal,
            irq        => irq
        );

    -- GPU Engine Instanz
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
            hsync      => hsync_internal,
            vsync      => vsync_internal,
            video_on   => video_on_internal,
            red        => red,
            green      => green,
            blue       => blue
        );

    hsync    <= hsync_internal;
    vsync    <= vsync_internal;
    video_on <= video_on_internal;

end Structural;