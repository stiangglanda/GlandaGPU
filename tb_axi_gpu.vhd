library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

entity tb_axi_gpu is
end tb_axi_gpu;

architecture sim of tb_axi_gpu is

    -- Component Declaration for the Unit Under Test (UUT)
    component axi_gpu_wrapper
        generic (
            C_S_AXI_DATA_WIDTH : integer := 32;
            C_S_AXI_ADDR_WIDTH : integer := 32
        );
        port (
            S_AXI_ACLK    : in std_logic;
            S_AXI_ARESETN : in std_logic;
            S_AXI_AWADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
            S_AXI_AWVALID : in std_logic;
            S_AXI_AWREADY : out std_logic;
            S_AXI_WDATA   : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            S_AXI_WSTRB   : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
            S_AXI_WVALID  : in std_logic;
            S_AXI_WREADY  : out std_logic;
            S_AXI_BRESP   : out std_logic_vector(1 downto 0);
            S_AXI_BVALID  : out std_logic;
            S_AXI_BREADY  : in std_logic;
            S_AXI_ARADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
            S_AXI_ARVALID : in std_logic;
            S_AXI_ARREADY : out std_logic;
            S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            S_AXI_RRESP   : out std_logic_vector(1 downto 0);
            S_AXI_RVALID  : out std_logic;
            S_AXI_RREADY  : in std_logic;
            hsync     : out std_logic;
            vsync     : out std_logic;
            video_on  : out std_logic;
            red       : out std_logic_vector(3 downto 0);
            green     : out std_logic_vector(3 downto 0);
            blue      : out std_logic_vector(3 downto 0);
            irq       : out std_logic
        );
    end component;

    -- Signals
    signal clk           : std_logic := '0';
    signal reset_n       : std_logic := '0';
    
    -- AXI Signals
    signal s_axi_awaddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axi_awprot  : std_logic_vector(2 downto 0) := "000";
    signal s_axi_awvalid : std_logic := '0';
    signal s_axi_awready : std_logic;
    signal s_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axi_wstrb   : std_logic_vector(3 downto 0) := "1111";
    signal s_axi_wvalid  : std_logic := '0';
    signal s_axi_wready  : std_logic;
    signal s_axi_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_bvalid  : std_logic;
    signal s_axi_bready  : std_logic := '0';
    signal s_axi_araddr  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axi_arprot  : std_logic_vector(2 downto 0) := "000";
    signal s_axi_arvalid : std_logic := '0';
    signal s_axi_arready : std_logic;
    signal s_axi_rdata   : std_logic_vector(31 downto 0);
    signal s_axi_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_rvalid  : std_logic;
    signal s_axi_rready  : std_logic := '0';

    -- GPU Output Signals
    signal hsync     : std_logic;
    signal vsync     : std_logic;
    signal video_on  : std_logic;
    signal red       : std_logic_vector(3 downto 0);
    signal green     : std_logic_vector(3 downto 0);
    signal blue      : std_logic_vector(3 downto 0);
    signal irq       : std_logic;

    -- Simulation Control
    constant CLK_PERIOD : time := 40 ns; -- 25 MHz
    signal sim_running  : boolean := true;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: axi_gpu_wrapper
        port map (
            S_AXI_ACLK    => clk,
            S_AXI_ARESETN => reset_n,
            S_AXI_AWADDR  => s_axi_awaddr,
            S_AXI_AWPROT  => s_axi_awprot,
            S_AXI_AWVALID => s_axi_awvalid,
            S_AXI_AWREADY => s_axi_awready,
            S_AXI_WDATA   => s_axi_wdata,
            S_AXI_WSTRB   => s_axi_wstrb,
            S_AXI_WVALID  => s_axi_wvalid,
            S_AXI_WREADY  => s_axi_wready,
            S_AXI_BRESP   => s_axi_bresp,
            S_AXI_BVALID  => s_axi_bvalid,
            S_AXI_BREADY  => s_axi_bready,
            S_AXI_ARADDR  => s_axi_araddr,
            S_AXI_ARPROT  => s_axi_arprot,
            S_AXI_ARVALID => s_axi_arvalid,
            S_AXI_ARREADY => s_axi_arready,
            S_AXI_RDATA   => s_axi_rdata,
            S_AXI_RRESP   => s_axi_rresp,
            S_AXI_RVALID  => s_axi_rvalid,
            S_AXI_RREADY  => s_axi_rready,
            hsync         => hsync,
            vsync         => vsync,
            video_on      => video_on,
            red           => red,
            green         => green,
            blue          => blue,
            irq           => irq
        );

    -- Clock Process
    clk_process : process
    begin
        while sim_running loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_proc: process
        -- Helper: Simple Hex String Conversion (VHDL-87/93 compatible)
        function to_hex_string(slv : std_logic_vector) return string is
            constant hex_digits : string(1 to 16) := "0123456789ABCDEF";
            variable result : string(1 to slv'length/4);
            variable nibble : integer;
        begin
            for i in 0 to (slv'length/4)-1 loop
                nibble := to_integer(unsigned(slv(slv'length-1-(i*4) downto slv'length-4-(i*4))));
                result(i+1) := hex_digits(nibble+1);
            end loop;
            return result;
        end function;

        -- AXI Write Procedure
        procedure axi_write(addr : in integer; data : in std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            
            -- Setup Address and Data
            s_axi_awaddr  <= std_logic_vector(to_unsigned(addr, 32));
            s_axi_awvalid <= '1';
            s_axi_wdata   <= data;
            s_axi_wstrb   <= "1111";
            s_axi_wvalid  <= '1';
            s_axi_bready  <= '1'; 

            -- Wait for AWREADY and WREADY
            loop 
                if s_axi_awready = '1' then
                    s_axi_awvalid <= '0';
                end if;
                if s_axi_wready = '1' then
                    s_axi_wvalid <= '0';
                end if;
                
                wait until rising_edge(clk);
                exit when (s_axi_awready = '1' and s_axi_wready = '1') or
                          (s_axi_awvalid = '0' and s_axi_wvalid = '0') or 
                          (s_axi_awvalid = '0' and s_axi_wready = '1') or
                          (s_axi_awready = '1' and s_axi_wvalid = '0');
            end loop;
            
            s_axi_awvalid <= '0';
            s_axi_wvalid  <= '0';
            
            -- Wait for Write Response
            while s_axi_bvalid = '0' loop
                wait until rising_edge(clk);
            end loop;
            
            s_axi_bready <= '0';
            
        end procedure;

        -- AXI Read Procedure
        procedure axi_read(addr : in integer; expected : in std_logic_vector(31 downto 0)) is
             variable read_value : std_logic_vector(31 downto 0);
        begin
            wait until rising_edge(clk);
            
            s_axi_araddr  <= std_logic_vector(to_unsigned(addr, 32));
            s_axi_arvalid <= '1';
            s_axi_rready  <= '1';

            -- Wait for Address Accepted
            loop
                wait until rising_edge(clk);
                exit when s_axi_arready = '1';
            end loop;
            
            s_axi_arvalid <= '0';
            
            -- Wait for Data Valid
            while s_axi_rvalid = '0' loop
                wait until rising_edge(clk);
            end loop;
            
            read_value := s_axi_rdata;
            s_axi_rready <= '0';
            
            if read_value /= expected then
                report "Read Mismatch at Address " & integer'image(addr) & 
                       ". Expected 0x" & to_hex_string(expected) & 
                       ", Got 0x" & to_hex_string(read_value)
                       severity failure;
            end if;
        end procedure;

        procedure cpu_write(addr_idx : in integer; data : in std_logic_vector(31 downto 0)) is
            variable full_addr : integer;
        begin
             -- Base 0x200000 + offset
             full_addr := 16#200000# + (addr_idx * 4);
             axi_write(full_addr, data);
        end procedure;

        procedure vram_write(offset : in integer; color : in std_logic_vector(11 downto 0)) is
            variable full_addr : integer;
            variable data_pad : std_logic_vector(31 downto 0);
        begin
            full_addr := offset * 4;
            data_pad := x"00000" & color;
            axi_write(full_addr, data_pad);
        end procedure;

    begin
        -- Hold Reset
        reset_n <= '0';
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;
        
        report "Starting AXI GPU Test";

        -- Reg 6 -> 0x03
        report "Enabling Interrupts via AXI";
        cpu_write(6, x"00000003");

        -- VRAM Write
        report "Writing to VRAM via AXI";
        vram_write(0, x"F00"); -- Red
        vram_write(1, x"0F0"); -- Green
        
        -- Verify VRAM Writes
        report "Verifying VRAM Writes";
        axi_read(0, x"00000F00"); -- Expect Red
        axi_read(4, x"000000F0"); -- Expect Green

        -- Draw Rectangle
        report "Draw Rectangle via AXI";

        cpu_write(2, x"000A000A"); -- Coord0: Y=10, X=10
        cpu_write(3, x"00320032"); -- Coord1: H=50, W=50
        cpu_write(4, x"0000000F"); -- Color: Blue
        cpu_write(1, x"00000012"); -- Ctrl: Start=1, CMD=2 (Rect) 

        wait for 200 us; -- Wait for draw

        -- Verify Rectangle
        -- Check pixel at (10,10): Index = 10*640 + 10 = 6410. Byte Addr = 6410 * 4 = 25640
        report "Verifying Rectangle Draw";
        axi_read(25640, x"0000000F"); -- Expect Blue at (10,10)

        report "Simulation Completed Successfully";
        sim_running <= false;
        wait;
    end process;
    
end sim;
