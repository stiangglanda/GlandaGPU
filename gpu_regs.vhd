library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gpu_regs is
    Port (
        clk       : in  std_logic;
        reset     : in  std_logic;

        -- Bus Interface
        bus_addr  : in  std_logic_vector(3 downto 0);
        bus_we    : in  std_logic;
        bus_din   : in  std_logic_vector(31 downto 0);
        bus_dout  : out std_logic_vector(31 downto 0);

        -- Register Interface
        gpu_x0, gpu_y0 : out unsigned(9 downto 0);
        gpu_x1, gpu_y1 : out unsigned(9 downto 0);
        gpu_color      : out std_logic_vector(11 downto 0);
        gpu_cmd        : out std_logic_vector(3 downto 0);
        gpu_start      : out std_logic;
        gpu_busy       : in  std_logic;
        vga_vsync      : in  std_logic
    );
end gpu_regs;

architecture Behavioral of gpu_regs is
    signal reg_coord0 : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_coord1 : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_color  : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_ctrl   : std_logic_vector(31 downto 0) := (others => '0');
    
    signal start_pulse : std_logic := '0';
begin

    -- Write-Logik (CPU -> GPU)
    process(clk)
    begin
        if rising_edge(clk) then
            start_pulse <= '0';
            if reset = '1' then
                reg_coord0 <= (others => '0');
                reg_coord1 <= (others => '0');
                reg_color  <= (others => '0');
                reg_ctrl   <= (others => '0');
            elsif bus_we = '1' then
                case bus_addr is
                    when x"1" => 
                        reg_ctrl   <= bus_din; 
                        start_pulse <= bus_din(4);
                    when x"2" =>
                        reg_coord0 <= bus_din;
                    when x"3" => 
                        reg_coord1 <= bus_din;
                    when x"4" => 
                        reg_color  <= bus_din;
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    -- Read-Logik (GPU -> CPU)
    process(bus_addr, gpu_busy, vga_vsync, reg_ctrl, reg_coord0, reg_coord1, reg_color)
    begin
        case bus_addr is
            when x"0" => 
                bus_dout <= (31 downto 2 => '0') & vga_vsync & (gpu_busy or start_pulse);-- or start_pulse! because this bridges the gap between Register Write and GPU Busy going high
            when x"1" => 
                bus_dout <= reg_ctrl;
            when x"2" => 
                bus_dout <= reg_coord0;
            when x"3" => 
                bus_dout <= reg_coord1;
            when x"4" => 
                bus_dout <= reg_color;
            when others => 
                bus_dout <= (others => '0');
        end case;
    end process;

    gpu_x0    <= unsigned(reg_coord0(9 downto 0));
    gpu_y0    <= unsigned(reg_coord0(25 downto 16));
    gpu_x1    <= unsigned(reg_coord1(9 downto 0));
    gpu_y1    <= unsigned(reg_coord1(25 downto 16));
    gpu_color <= reg_color(11 downto 0);
    gpu_cmd   <= reg_ctrl(3 downto 0);
    gpu_start <= start_pulse;

end Behavioral;