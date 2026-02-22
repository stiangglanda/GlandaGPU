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
        -- Read/Write to VRAM
        we_a    : in  std_logic;
        addr_a  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        din_a   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        dout_a  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- Read from VRAM
        addr_b  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        dout_b  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end vram;

architecture Behavioral of vram is
    constant RAM_DEPTH : integer := 307200; -- 640x480
    type ram_type is array (0 to RAM_DEPTH - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Block RAM inference
    signal ram : ram_type;
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M10K, no_rw_check"; -- Force block RAM (M10K for Cyclone V)

begin

    -- Port A: Read/Write
    process(clk)
        variable addr_a_int : integer;
    begin
        if rising_edge(clk) then
            addr_a_int := to_integer(unsigned(addr_a));
            if addr_a_int >= RAM_DEPTH then
                addr_a_int := 0;
            end if;
            
            if we_a = '1' then
                ram(addr_a_int) <= din_a;
            end if;
            dout_a <= ram(addr_a_int);
        end if;
    end process;

    -- Port B: Read Only
    process(clk)
        variable addr_b_int : integer;
    begin
        if rising_edge(clk) then
            addr_b_int := to_integer(unsigned(addr_b));
            if addr_b_int >= RAM_DEPTH then
                addr_b_int := 0;
            end if;
            
            dout_b <= ram(addr_b_int);
        end if;
    end process;

end Behavioral;