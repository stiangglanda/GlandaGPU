library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gpu_engine is
    Port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        -- Register Interface
        reg_cmd      : in  std_logic_vector(3 downto 0); -- 1=Rect, 2=Clear
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
    type state_type is (IDLE, FETCH_CMD, STATE_RECT, STATE_CLEAR);
    signal state : state_type := IDLE;
    
    signal curr_x, curr_y : unsigned(9 downto 0);
    signal clear_addr     : unsigned(18 downto 0);
    
    constant VRAM_MAX_ADDR : integer := 307200;
begin

    process(clk)
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
                            curr_x <= (others => '0');
                            curr_y <= (others => '0');
                            state <= STATE_RECT;
                        elsif reg_cmd = x"2" then
                            clear_addr <= (others => '0');
                            state <= STATE_CLEAR;
                        else
                            state <= IDLE; -- Unknown command
                        end if;

                    when STATE_RECT =>
                        vram_we <= '1';
                        vram_addr <= std_logic_vector(resize((reg_y + curr_y) * 640 + (reg_x + curr_x), 19));
                        vram_din  <= reg_color;

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

                    when STATE_CLEAR =>
                        vram_we <= '1';
                        vram_addr <= std_logic_vector(clear_addr);
                        vram_din  <= reg_color;

                        if clear_addr < VRAM_MAX_ADDR - 1 then
                            clear_addr <= clear_addr + 1;
                        else
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;