library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vram is
    generic (
        ADDR_WIDTH : integer := 19; -- 2^19 = 524.288 more then needed (640x480)
        DATA_WIDTH : integer := 12  -- 4-4-4 RGB
    );
    port (
        clk     : in  std_logic;
        -- Write to VRAM
        we_a    : in  std_logic;
        addr_a  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        din_a   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        -- Read from VRAM
        addr_b  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        dout_b  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end vram;

architecture Behavioral of vram is
    type ram_type is array (0 to 307199) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_type := (others => (others => '0')); -- Initialise with black
begin
    -- Write to VRAM
    process(clk)
    begin
        if rising_edge(clk) then
            if we_a = '1' then
                ram(to_integer(unsigned(addr_a))) <= din_a;
            end if;
        end if;
    end process;

    -- Read from VRAM
    process(clk)
    variable addr_int : integer;
    begin
        if rising_edge(clk) then
            addr_int := to_integer(unsigned(addr_b));
            if addr_int < 307200 then
                dout_b <= ram(addr_int);
            else
                dout_b <= (others => '0'); -- Out of bounds, return black
            end if;
        end if;
    end process;
end Behavioral;