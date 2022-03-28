----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/19/2022 08:31:17 PM
-- Design Name: 
-- Module Name: lab5_top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
    


entity lab5_top is
  Port (
    -- 100MHz system clock
    clk : in std_logic;

    -- active high reset switch
    RESET_SW : in std_logic;

    -- toggle between ACL and PUSHBUTTON control
    ACL_EN : in std_logic;

    -- select which values to display on digits 7-4 of 7-seg
    DISP : in std_logic_vector (1 downto 0);
        -- 00 - show IDs
        -- 01 - show x on 5,4 (00 in 7,6)
        -- 10 - show y on 5,4 (00 in 7,6)
        -- 11 - show z on 5,4 (00 in 7,6)

    -- push buttons
    BTNU : in STD_LOGIC;
    BTND : in STD_LOGIC;
    BTNL : in STD_LOGIC;
    BTNR : in STD_LOGIC;

    -- VGA
    RED : out std_logic_vector(3 downto 0);
    GRN : out std_logic_vector(3 downto 0);
    BLU : out std_logic_vector(3 downto 0);
    VS : out std_logic;
    HS : out std_logic;

    -- 7 segment signals
    SEG7_CATH : out STD_LOGIC_VECTOR (7 downto 0);
    AN : out STD_LOGIC_VECTOR (7 downto 0);

    -- LEDS
    LED : out std_logic_vector(3 downto 0);  

    -- spi interface to accelerometer
    ACL_CSN : out std_logic;
    ACL_MOSI : out std_logic;
    ACL_SCLK : out std_logic;
    ACL_MISO : in std_logic );

    

end lab5_top;

architecture arch of lab5_top is

    signal reset : std_logic; -- signal to assert reset downstream to other entites
    signal pulse : std_logic; -- capture output from pulse generator

    -- 4-bit hex for each 7 segment character
    signal c1 :  STD_LOGIC_VECTOR(3 downto 0);
    signal c2 :  STD_LOGIC_VECTOR(3 downto 0);
    signal c3 :  STD_LOGIC_VECTOR(3 downto 0);
    signal c4 :  STD_LOGIC_VECTOR(3 downto 0);
    signal c5 :  STD_LOGIC_VECTOR(3 downto 0);
    signal c6 :  STD_LOGIC_VECTOR(3 downto 0);
    signal c7 :  STD_LOGIC_VECTOR(3 downto 0);
    signal c8 :  STD_LOGIC_VECTOR(3 downto 0);
    
     -- 25MHZ pixel clock
    signal pulse25 : std_logic;

    -- track red block index (x 0 to 20, y 0 to 15), 8 bits each for 7-seg convenience
    signal blockx : unsigned(7 downto 0) := x"0a";
    signal blocky : unsigned(7 downto 0) := x"07";

    -- debounced button pulses
    signal u_db : std_logic := '0';
    signal d_db : std_logic := '0';
    signal l_db : std_logic := '0';
    signal r_db : std_logic := '0';

    -- debounced accelerometer pulses
    signal acl_xinc : std_logic := '0';
    signal acl_xdec : std_logic := '0';
    signal acl_yinc : std_logic := '0';
    signal acl_ydec : std_logic := '0';

    -- accelerometer data
    signal DATA_X : std_logic_vector(7 downto 0) := x"00";
    signal DATA_Y : std_logic_vector(7 downto 0):= x"00";
    signal DATA_Z : std_logic_vector(7 downto 0):= x"00";
    signal ID_AD : std_logic_vector(7 downto 0):= x"00";
    signal ID_1D : std_logic_vector(7 downto 0):= x"00";

begin

    seg7 : entity work.seg7_controller port map (
        clk => clk,
        rst => reset,
        c1 => c1,
        c2 => c2,
        c3 => c3,
        c4 => c4,
        c5 => c5,
        c6 => c6,
        c7 => c7,
        c8 => c8,
        anodes => AN,
        cathodes => SEG7_CATH
    );

    pxclk : entity work.pulse_gen port map (
        clk => clk,
        rst => reset,
        pulse => pulse25,
        trig => x"0000003" -- 100MHz/4 => 25MHz
    );

    vga : entity work.vga_controller port map (
        clk => clk,
        rst => reset,
        pulse25 => pulse25,
        x => blockx,
        y => blocky,
        HS => HS,
        VS => VS,
        RED => RED,
        GRN => GRN,
        BLU => BLU
    );

    -- debounce all four buttons
    up : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => BTNU,
        debounced => u_db
    );

    left : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => BTNL,
        debounced => l_db
    );

    down : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => BTND,
        debounced => d_db
    );

    right : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => BTNR,
        debounced => r_db
    );

    -- acceleromter r/w entity, implements FSMs from hints to capture X,Y,Z & IDs
    accel_spi_rw : entity acl_spi_rw port map (
		clk => clk,
		reset =>  reset,
		--Values from Accelerometer
		data_x => DATA_X,
		data_y => DATA_Y,
		data_z => DATA_Z,
		id_ad => ID_AD,
		id_1d => ID_1D,
		--SPI Signals
		cs => ACL_CSN,
		mosi => ACL_MOSI,
		sclk => ACL_SCLK,
		miso => ACL_MISO 
    );

    -- just treating the relevant acl bits as debouncable buttons for some code reuse
    xinc : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => DATA_X(7),
        debounced => acl_xinc
    );
    xdec : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => DATA_X(6),
        debounced => acl_xdec
    );
    yinc : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => DATA_Y(7),
        debounced => acl_yinc
    );
    ydec : entity work.debounce port map (
        clk => clk,
        rst => reset,
        button_state => DATA_Y(6),
        debounced => acl_ydec
    );

        
    top : process (clk, RESET_SW)
    begin
        if (RESET_SW = '1') then
            -- pass along the reset signal
            reset <= '1';

            -- reset block position
            blockx <= x"0a";
            blocky <= x"07";

        elsif (rising_edge(clk)) then
            reset <= '0';

            if (ACL_EN ='0') then
                -- monitors debounce states and updates red block position accordingly
                if (u_db = '1') then
                    -- decrement y, wrap at 0
                    if (blocky > 0) then
                        blocky <= blocky - 1;
                    else
                        blocky <= x"0e";
                    end if;
                end if;

                if (d_db = '1') then
                    -- increment y, stop at 14
                    if (blocky < 14) then
                        blocky <= blocky + 1;
                    else
                        blocky <= x"00";
                    end if;
                end if;

                if (l_db = '1') then
                    -- decrement x, wrap to 19 at 0
                    if (blockx > 0) then
                        blockx <= blockx - 1;
                    else
                        blockx <= x"13";
                    end if;
                end if;

                if (r_db = '1') then
                    -- increment x, wrap to 0 at 19
                    if (blockx < 19) then
                        blockx <= blockx + 1;
                    else
                        blockx <= x"00";
                    end if;
                end if;

            else 
                -- set red block coordinates by ACL data
                if (acl_xinc = '1') then
                    -- increment x, wrap to 0 at 19
                    if (blockx < 19) then
                        blockx <= blockx + 1;
                    else
                        blockx <= x"00";
                    end if;
                elsif acl_xdec = '1' then
                    -- decrement x, wrap to 19 at 0
                    if (blockx > 0) then
                        blockx <= blockx - 1;
                    else
                        blockx <= x"13";
                    end if;
                end if;

                if acl_yinc = '1' then 
                    -- increment y, stop at 14
                    if (blocky < 14) then
                        blocky <= blocky + 1;
                    else
                        blocky <= x"00";
                    end if;
                elsif acl_ydec = '1' then
                    -- decrement y, wrap at 0
                    if (blocky > 0) then
                        blocky <= blocky - 1;
                    else
                        blocky <= x"0e";
                    end if;
                end if;
            end if;

        end if;
    end process;

    -- 7 segment display character assignment

    --X,Y is always on char 4 through 0
    c2 <= std_logic_vector(blocky(7 downto 4));
    c1 <= std_logic_vector(blocky(3 downto 0));

    c4 <= std_logic_vector(blockx(7 downto 4));
    c3 <= std_logic_vector(blockx(3 downto 0));

    -- 7,6 is IDAD (addr 0x00) when 00, else zeroes 
    c8 <= ID_AD(7 downto 4) when DISP = "00" else "0000";
    c7 <= ID_AD(3 downto 0) when DISP = "00" else "0000";

    -- assign 5,4 based on listed requirements
    -- will be either xdata, ydata, zdata, or id1d (addr 0x01)
    with DISP select
        c6 <= DATA_X(7 downto 4) when "01",
              DATA_Y(7 downto 4) when "10",
              DATA_Z(7 downto 4) when "11",
              ID_1D(7 downto 4) when others;
    
    with DISP select
        c5 <= DATA_X(3 downto 0) when "01",
            DATA_Y(3 downto 0) when "10",
            DATA_Z(3 downto 0) when "11",
            ID_1D(3 downto 0) when others;


    -- buttons to LEDs for sanity check on debounce/press
    LED(0) <= BTNU;
    LED(1) <= BTND;
    LED(2) <= BTNL;
    LED(3) <= BTNR;
end arch;


