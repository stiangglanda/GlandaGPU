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
        vga_vsync      : in  std_logic;

        irq : out std_logic
    );
end gpu_regs;

architecture Behavioral of gpu_regs is
    signal reg_coord0 : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_coord1 : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_color  : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_ctrl   : std_logic_vector(31 downto 0) := (others => '0');
    
    signal start_pulse : std_logic := '0';

    signal reg_ie : std_logic_vector(31 downto 0) := (others => '0'); -- Interrupt Enable Register (0=Done, 1=VSync)
    signal reg_ip : std_logic_vector(31 downto 0) := (others => '0'); -- IP = Interrupt Pending

    signal busy_old   : std_logic := '0';
    signal vsync_old  : std_logic := '0';
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
        bus_dout <= (others => '0'); 

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
            when x"5" => 
                bus_dout <= reg_ip; 
            when x"6" => 
                bus_dout <= reg_ie;
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

    -- Interrupt Management
    process(clk)
        variable ip_next : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk) then
            busy_old  <= gpu_busy;
            vsync_old <= vga_vsync;

            if reset = '1' then
                reg_ip <= (others => '0');
                reg_ie <= (others => '0'); -- IE auch hier resetten
            else
                ip_next := reg_ip;

                -- write delete/clear interrupts
                if bus_we = '1' then
                    if bus_addr = x"5" then -- ISR (W1C)
                        ip_next := ip_next and (not bus_din);
                    end if;

                    if bus_addr = x"6" then -- IER
                        reg_ie <= bus_din;
                    end if;
                end if;

                -- Detect Busy interrupt (Falling Edge)
                if busy_old = '1' and gpu_busy = '0' then
                    ip_next(0) := '1';
                end if;
                
                -- Detect VSync interrupt (Falling Edge)
                if vsync_old = '1' and vga_vsync = '0' then
                    ip_next(1) := '1';
                end if;

                reg_ip <= ip_next;

            end if;
        end if;
    end process;

    -- raise an interrupt if pending and enabled
    irq <= '1' when (reg_ip and reg_ie) /= x"00000000" else '0';


end Behavioral;