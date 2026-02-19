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
	 
	signal video_on_int : std_logic;

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

    -- Sync Signal Generation
    process(clk)
    begin
        if rising_edge(clk) then
            -- Horizontal Sync
            if (h_cnt >= (H_ACTIVE + H_FP)) and (h_cnt < (H_ACTIVE + H_FP + H_SYNC)) then
                hsync <= '0';
            else
                hsync <= '1';
            end if;

            -- Vertical Sync
            if (v_cnt >= (V_ACTIVE + V_FP)) and (v_cnt < (V_ACTIVE + V_FP + V_SYNC)) then
                vsync <= '0';
            else
                vsync <= '1';
            end if;
        end if;
    end process;
    
    -- Video On
	video_on_int <= '1' when (h_cnt < H_ACTIVE) and (v_cnt < V_ACTIVE) else '0';
	video_on <= video_on_int;

    -- Read pixel from VRAM
    pixel_addr <= std_logic_vector(to_unsigned(v_cnt * 640 + h_cnt, 19)) 
              when (video_on_int = '1') else (others => '0');

    process(clk)
    begin
        if rising_edge(clk) then
            if video_on_int = '1' then
                red   <= pixel_data(11 downto 8); -- TODO delay problem pixel kommt erst im nächsten takt
                green <= pixel_data(7 downto 4);  -- erster Pixel ist immer schwarz, da pixel_data erst im nächsten Takt gültig ist
                blue  <= pixel_data(3 downto 0);
            else
                red <= "0000"; green <= "0000"; blue <= "0000";
            end if;
        end if;
    end process;

end Behavioral;