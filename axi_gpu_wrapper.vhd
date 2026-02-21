library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi_gpu_wrapper is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 32
    );
    port (
        -- Global Clock and Reset
        S_AXI_ACLK    : in std_logic;
        S_AXI_ARESETN : in std_logic;

        -- AXI4-Lite Write Address Channel
        S_AXI_AWADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
        S_AXI_AWVALID : in std_logic;
        S_AXI_AWREADY : out std_logic;

        -- AXI4-Lite Write Data Channel
        S_AXI_WDATA   : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in std_logic;
        S_AXI_WREADY  : out std_logic;

        -- AXI4-Lite Write Response Channel
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in std_logic;

        -- AXI4-Lite Read Address Channel
        S_AXI_ARADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
        S_AXI_ARVALID : in std_logic;
        S_AXI_ARREADY : out std_logic;

        -- AXI4-Lite Read Data Channel
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in std_logic;

        -- External GPU Interface Signals (VGA, IRQ)
        hsync     : out std_logic;
        vsync     : out std_logic;
        video_on  : out std_logic;
        red       : out std_logic_vector(3 downto 0);
        green     : out std_logic_vector(3 downto 0);
        blue      : out std_logic_vector(3 downto 0);
        irq       : out std_logic
    );
end axi_gpu_wrapper;

architecture Behavioral of axi_gpu_wrapper is

    -- Component Declaration for top_gpu
    component top_gpu
        Port ( 
            clk   : in std_logic;
            reset : in std_logic;

            bus_addr   : in std_logic_vector(31 downto 0);
            bus_we     : in std_logic;
            bus_din    : in std_logic_vector(31 downto 0);
            bus_dout   : out std_logic_vector(31 downto 0);
            bus_wait   : out std_logic;

            hsync : out std_logic;
            vsync : out std_logic;
            video_on : out std_logic;
            red, green, blue : out std_logic_vector(3 downto 0);

            irq : out std_logic
        );
    end component;

    -- Internal Signals connection to top_gpu
    signal internal_reset : std_logic;
    signal bus_addr       : std_logic_vector(31 downto 0);
    signal bus_we         : std_logic;
    signal bus_din        : std_logic_vector(31 downto 0);
    signal bus_dout       : std_logic_vector(31 downto 0);
    signal bus_wait       : std_logic;

    -- AXI4-Lite Signals
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bvalid  : std_logic;
    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_arready : std_logic;
    signal axi_rvalid  : std_logic;
    signal axi_rdata   : std_logic_vector(31 downto 0);
    signal axi_rresp   : std_logic_vector(1 downto 0);

    -- State machine states
    type state_type is (IDLE, WRITE_ACCESS, WRITE_RESP, READ_ACCESS, READ_WAIT, READ_RESP);
    signal state : state_type := IDLE;

    -- Standard AXI response constants
    constant OKAY   : std_logic_vector(1 downto 0) := "00";

begin

    -- Reset logic: AXI is Active Low, Internal is Active High
    internal_reset <= not S_AXI_ARESETN;

    -- I/O Connections assignments
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= axi_bresp;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= axi_rresp;
    S_AXI_RVALID  <= axi_rvalid;

    -- Instantiate the top_gpu
    top_gpu_inst : top_gpu
    port map (
        clk      => S_AXI_ACLK,
        reset    => internal_reset,
        bus_addr => bus_addr,
        bus_we   => bus_we,
        bus_din  => bus_din,
        bus_dout => bus_dout,
        bus_wait => bus_wait,
        hsync    => hsync,
        vsync    => vsync,
        video_on => video_on,
        red      => red,
        green    => green,
        blue     => blue,
        irq      => irq
    );

    -- Main AXI Control Process
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                state       <= IDLE;
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_arready <= '0';
                axi_bvalid  <= '0';
                axi_rvalid  <= '0';
                axi_bresp   <= OKAY;
                axi_rresp   <= OKAY;
                axi_rdata   <= (others => '0');
                
                bus_addr    <= (others => '0');
                bus_we      <= '0';
                bus_din     <= (others => '0');
            else
                case state is
                    when IDLE =>
                        axi_bvalid <= '0';
                        axi_rvalid <= '0';
                        bus_we     <= '0';

                        -- Priority: Write before Read
                        if (S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') then
                            -- Acknowledge Write Address & Data
                            axi_awready <= '1';
                            axi_wready  <= '1';
                            
                            -- Capture Address & Data for internal bus
                            bus_addr <= S_AXI_AWADDR;
                            bus_din  <= S_AXI_WDATA;
                            bus_we   <= '1'; -- Assert Write Enable for internal bus
                            
                            state <= WRITE_ACCESS;
                            
                        elsif (S_AXI_ARVALID = '1') then
                            -- Acknowledge Read Address
                            axi_arready <= '1';
                            
                            -- Capture Address for internal bus
                            bus_addr <= S_AXI_ARADDR;
                            bus_we   <= '0'; -- Setup for Read
                            
                            state <= READ_WAIT;
                        else
                            axi_awready <= '0';
                            axi_wready  <= '0';
                            axi_arready <= '0';
                        end if;

                    when WRITE_ACCESS =>
                        -- Deassert Ready signals immediately after one cycle
                        axi_awready <= '0';
                        axi_wready  <= '0';

                        -- Wait for internal device to accept the write (bus_wait = '0')
                        if bus_wait = '0' then
                            bus_we <= '0';          -- Deassert internal WE
                            axi_bvalid <= '1';      -- Signal Write Response Valid
                            axi_bresp  <= OKAY;
                            state <= WRITE_RESP;
                        else
                            -- If wait is high, keep bus_we asserted and stay in this state
                            bus_we <= '1';
                        end if;

                    when WRITE_RESP =>
                        -- Wait for Master to accept response (BREADY)
                        if S_AXI_BREADY = '1' then
                            axi_bvalid <= '0';
                            state <= IDLE;
                        else
                            -- Stay valid until accepted
                            axi_bvalid <= '1';
                        end if;
                    
                    when READ_WAIT =>
                        -- Wait state for synchronous memory read latency
                        state <= READ_ACCESS;

                    when READ_ACCESS =>
                        -- Deassert Ready signal
                        axi_arready <= '0';

                        -- Wait for internal device to have data ready (bus_wait = '0')
                        if bus_wait = '0' then
                            axi_rdata  <= bus_dout; -- Capture data
                            axi_rvalid <= '1';      -- Signal Read Data Valid
                            axi_rresp  <= OKAY;
                            state <= READ_RESP;
                        end if;

                    when READ_RESP =>
                        -- Wait for Master to accept data (RREADY)
                        if S_AXI_RREADY = '1' then
                            axi_rvalid <= '0';
                            state <= IDLE;
                        else
                            -- Stay valid until accepted
                            axi_rvalid <= '1';
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
