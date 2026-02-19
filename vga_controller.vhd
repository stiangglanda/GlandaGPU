library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port ( 
        clk         : in  STD_LOGIC; -- 25 MHz
        reset       : in  STD_LOGIC;
        pixel_data  : in  STD_LOGIC_VECTOR(11 downto 0);
        pixel_addr  : out STD_LOGIC_VECTOR(18 downto 0);
        hsync       : out STD_LOGIC;
        vsync       : out STD_LOGIC;
		video_on    : out STD_LOGIC;
        red         : out STD_LOGIC_VECTOR (3 downto 0);
        green       : out STD_LOGIC_VECTOR (3 downto 0);
        blue        : out STD_LOGIC_VECTOR (3 downto 0)
    );
end vga_controller;

architecture Behavioral of vga_controller is

    -- VGA 640x480 @ 60Hz
    -- Horizontal (Pixels)
    constant H_ACTIVE  : integer := 640;
    constant H_FP      : integer := 16;-- Front Porch
    constant H_SYNC    : integer := 96;-- Sync Pulse
    constant H_BP      : integer := 48;-- Back Porch
    constant H_TOTAL   : integer := 800;

    -- Vertical (Lines)
    constant V_ACTIVE  : integer := 480;
    constant V_FP      : integer := 10;-- Front Porch
    constant V_SYNC    : integer := 2; -- Sync Pulse
    constant V_BP      : integer := 33;-- Back Porch
    constant V_TOTAL   : integer := 525;

    -- Counters
    signal h_cnt : integer range 0 to H_TOTAL - 1 := 0;
    signal v_cnt : integer range 0 to V_TOTAL - 1 := 0;

    -- fix for delay problem of VRAM
    signal hsync_i    : std_logic;
    signal vsync_i    : std_logic;
    signal video_on_i : std_logic;

    signal hsync_v1, hsync_v2       : std_logic := '1';
    signal vsync_v1, vsync_v2       : std_logic := '1';
    signal video_on_v1, video_on_v2 : std_logic := '0';

begin

    -- H and V Counters
    process(clk, reset)
    begin
        if reset = '1' then
            h_cnt <= 0;
            v_cnt <= 0;
        elsif rising_edge(clk) then
            -- Horizontal
            if h_cnt = H_TOTAL - 1 then
                h_cnt <= 0;
                -- Vertical
                if v_cnt = V_TOTAL - 1 then
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
                end if;
            else
                h_cnt <= h_cnt + 1;
            end if;
        end if;
    end process;

    -- Sync Signale berechnen Generation
    hsync_i <= '0' when (h_cnt >= (H_ACTIVE + H_FP)) and (h_cnt < (H_ACTIVE + H_FP + H_SYNC)) else '1';
    vsync_i <= '0' when (v_cnt >= (V_ACTIVE + V_FP)) and (v_cnt < (V_ACTIVE + V_FP + V_SYNC)) else '1';

    -- video_on Signal
    video_on_i <= '1' when (h_cnt < H_ACTIVE) and (v_cnt < V_ACTIVE) else '0';
    -- Calculate Pixeladdresse
    pixel_addr <= std_logic_vector(to_unsigned(v_cnt * 640 + h_cnt, 19)) 
                  when (video_on_i = '1') else (others => '0');

    -- Delay hsync, vsync und video_on for 2 Takte, so they are in sync with the PixelData from VRAM
    process(clk)
    begin
        if rising_edge(clk) then
            -- in Sync with VRAM output
            hsync_v1    <= hsync_i;
            vsync_v1    <= vsync_i;
            video_on_v1 <= video_on_i;
            
            -- in sync with the RGB output
            hsync_v2    <= hsync_v1;
            vsync_v2    <= vsync_v1;
            video_on_v2 <= video_on_v1;
        end if;
    end process;

    -- Fetch Pixel Data from VRAM
    process(clk)
    begin
        if rising_edge(clk) then
            -- use v1 so it is in sync with the VRAM output
            if video_on_v1 = '1' then
                red   <= pixel_data(11 downto 8);
                green <= pixel_data(7 downto 4);
                blue  <= pixel_data(3 downto 0);
            else
                red <= "0000"; 
                green <= "0000"; 
                blue <= "0000";
            end if;
        end if;
    end process;

    hsync    <= hsync_v2;
    vsync    <= vsync_v2;
    video_on <= video_on_v2;

end Behavioral;