library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gpu_engine is
    Port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        -- Register Interface
        reg_cmd      : in  std_logic_vector(3 downto 0); -- 1=Clear, 2=Rect, 3=Line
        reg_x        : in  unsigned(9 downto 0);
        reg_y        : in  unsigned(9 downto 0);
        reg_w        : in  unsigned(9 downto 0);
        reg_h        : in  unsigned(9 downto 0);
        reg_color    : in  std_logic_vector(11 downto 0);
        reg_start    : in  std_logic;
        busy         : out std_logic;
        -- VRAM Interface
        vram_we      : out std_logic;
        vram_addr    : out std_logic_vector(18 downto 0);
        vram_din     : out std_logic_vector(11 downto 0)
    );
end gpu_engine;

architecture Behavioral of gpu_engine is
    type state_type is (IDLE, FETCH_CMD, STATE_CLEAR, STATE_RECT, STATE_LINE_INIT, STATE_LINE_PREP, STATE_LINE_DRAW);
    signal state : state_type := IDLE;

    -- Register for Bresenham's Algorithm, using signed types for calculations
    signal x0, x1, y0, y1 : signed(11 downto 0) := (others => '0');
    signal dx, dy, err    : signed(11 downto 0) := (others => '0');
    signal sx, sy         : signed(11 downto 0) := (others => '0');
    
    signal curr_x, curr_y : unsigned(9 downto 0);
    signal clear_addr     : unsigned(18 downto 0);
    
    constant VRAM_MAX_ADDR : integer := 307200;
begin

    process(clk)

        variable v_err  : signed(11 downto 0);
        variable v_e2   : signed(11 downto 0);
        variable v_x0   : signed(11 downto 0);
        variable v_y0   : signed(11 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                busy <= '0';
                vram_we <= '0';
            else
                case state is
                    when IDLE =>
                        busy <= '0';
                        vram_we <= '0';
                        if reg_start = '1' then
                            busy <= '1';
                            state <= FETCH_CMD;
                        end if;

                    when FETCH_CMD => -- CMD Dispatcher
                        if reg_cmd = x"1" then
                            clear_addr <= (others => '0');
                            state <= STATE_CLEAR;
                        elsif reg_cmd = x"2" then
                            curr_x <= (others => '0'); 
                            curr_y <= (others => '0');
                            state <= STATE_RECT;
                        elsif reg_cmd = x"3" then
                            -- Convert to 12-bit (prepend 00 for unsigned -> signed)
                            x0 <= signed("00" & reg_x);
                            y0 <= signed("00" & reg_y);
                            x1 <= signed("00" & reg_w);
                            y1 <= signed("00" & reg_h);
                            state <= STATE_LINE_INIT;
                        else
                            state <= IDLE; -- Unknown command
                        end if;
                    
                    when STATE_CLEAR =>
                        vram_we <= '1';
                        vram_addr <= std_logic_vector(clear_addr);
                        vram_din  <= reg_color;

                        if clear_addr < VRAM_MAX_ADDR - 1 then
                            clear_addr <= clear_addr + 1;
                        else
                            state <= IDLE;
                        end if;

                    when STATE_RECT =>
                        if (to_integer(reg_y + curr_y) < 480) and (to_integer(reg_x + curr_x) < 640) then
                            vram_we   <= '1';
                            vram_addr <= std_logic_vector(to_unsigned((to_integer(reg_y) + to_integer(curr_y)) * 640 + (to_integer(reg_x) + to_integer(curr_x)), 19));
                            vram_din  <= reg_color;
                        else vram_we <= '0';
                        end if;

                        if curr_x < reg_w - 1 then
                            curr_x <= curr_x + 1;
                        else
                            curr_x <= (others => '0');
                            if curr_y < reg_h - 1 then
                                curr_y <= curr_y + 1;
                            else
                                state <= IDLE; -- done
                            end if;
                        end if;

                    when STATE_LINE_INIT => -- Bresenham's Line Algorithm
                        dx <= abs(x1 - x0);
                        dy <= -abs(y1 - y0);
                        
                        if x0 < x1 then 
                            sx <= to_signed(1, 12); 
                        else 
                            sx <= to_signed(-1, 12); 
                        end if;

                        if y0 < y1 then 
                            sy <= to_signed(1, 12); 
                        else 
                            sy <= to_signed(-1, 12); 
                        end if;
                        state <= STATE_LINE_PREP;

                    when STATE_LINE_PREP =>
                        err <= dx + dy;
                        state <= STATE_LINE_DRAW;

                    when STATE_LINE_DRAW =>
                        if x0 >= 0 and x0 < 640 and y0 >= 0 and y0 < 480 then
                            vram_we   <= '1';
                            vram_addr <= std_logic_vector(to_unsigned(to_integer(y0) * 640 + to_integer(x0), 19));
                            vram_din  <= reg_color;
                        else
                            vram_we <= '0';
                        end if;

                        v_x0  := x0;
                        v_y0  := y0;
                        v_err := err;

                        if v_x0 = x1 and v_y0 = y1 then
                            state <= IDLE;
                        else
                            v_e2 := v_err + v_err; -- e2 = 2*err
                            
                            if v_e2 >= dy then
                                v_err := v_err + dy;
                                v_x0  := v_x0 + sx;
                            end if;
                            
                            if v_e2 <= dx then
                                v_err := v_err + dx;
                                v_y0  := v_y0 + sy;
                            end if;

                            x0  <= v_x0;
                            y0  <= v_y0;
                            err <= v_err;
                        end if;

                    when others => state <= IDLE;
                end case;
            end if;
        end if;
    end process;
end Behavioral;