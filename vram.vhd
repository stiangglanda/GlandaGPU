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
    -- Use full address space for Block RAM inference (2^19 = 524,288)
    type ram_type is array (0 to 2**ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Block RAM inference
    signal ram : ram_type;
    attribute ram_style : string;
    attribute ram_style of ram : signal is "M10K"; -- Force block RAM (M10K for Cyclone V)

begin

    -- Port A: Read/Write
    process(clk)
    begin
        if rising_edge(clk) then
            if we_a = '1' then
                ram(to_integer(unsigned(addr_a))) <= din_a;
            end if;
            dout_a <= ram(to_integer(unsigned(addr_a)));
        end if;
    end process;

    -- Port B: Read Only
    process(clk)
    begin
        if rising_edge(clk) then
            dout_b <= ram(to_integer(unsigned(addr_b)));
        end if;
    end process;

end Behavioral;