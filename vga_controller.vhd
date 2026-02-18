library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port ( 
        clk     : in  STD_LOGIC; -- 25 MHz
        reset   : in  STD_LOGIC;
        hsync   : out STD_LOGIC;
        vsync   : out STD_LOGIC;
		  video_on: out STD_LOGIC;
        red     : out STD_LOGIC_VECTOR (3 downto 0);
        green   : out STD_LOGIC_VECTOR (3 downto 0);
        blue    : out STD_LOGIC_VECTOR (3 downto 0)
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
    
    -- Pattern Generator(Drawing Logic)
    process(clk)
    begin
        if rising_edge(clk) then
            if video_on_int = '1' then
                -- white box
                if (h_cnt > 100 and h_cnt < 150) and (v_cnt > 100 and v_cnt < 150) then
                    red   <= "1111"; 
                    green <= "1111";
                    blue  <= "1111";
                elsif h_cnt < 213 then -- left red
                    red   <= "1111";
                    green <= "0000";
                    blue  <= "0000";
                elsif h_cnt < 426 then -- middle green
                    red   <= "0000";
                    green <= "1111";
                    blue  <= "0000";
                else -- right blue
                    red   <= "0000";
                    green <= "0000";
                    blue  <= "1111";
                end if;

            else
                -- BLANKING INTERVAL IMPORTANT!
                red   <= "0000";
                green <= "0000";
                blue  <= "0000";
            end if;
        end if;
    end process;

end Behavioral;