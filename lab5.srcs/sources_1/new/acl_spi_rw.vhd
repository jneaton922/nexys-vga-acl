

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity acl_spi_rw is
    Port(
        clk: in std_logic; -- master 100 MHz system clock
        reset: in std_logic; -- asynch active high reset

        -- acl values for mvmt and display
        data_x : out std_logic_vector(7 downto 0); --8-bit x reading, address 0x08
        data_y : out std_logic_vector(7 downto 0); --8-bit y reading, address 0x09
        data_z : out std_logic_vector(7 downto 0); --8-bit z reading, address 0x0a
        id_ad : out std_logic_vector(7 downto 0); --value in 0x00, device id (ad)
        id_1d : out std_logic_vector(7 downto 0); --value in 0x01, device id (1d)

        -- spi signals
        cs : out std_logic := '1'; -- chip-select (active low)
        mosi : out std_logic := '0'; -- master-out (slave in)
        sclk : out std_logic := '0'; -- spi clock (1 MHz)
        miso : in std_logic -- master-in (slave-out)
    );
end acl_spi_rw;

architecture arch of acl_spi_rw is

    signal SPIstart : std_logic; -- trigger from command to SPI
    signal SPIdone  : std_logic; -- acknowledge from SPI back to command

    signal toSPIbytes : std_logic_vector(23 downto 0); -- three byte commands ~= <command address data>

    -- timer signals
    signal tim_start : std_logic;
    signal tim_done : std_logic;

    -- need 17 bits for 100 ms timer @ 100MHz
    signal tim_max : unsigned(16 downto 0);
    signal tim_cntr : unsigned(16 downto 0); 

    signal sclkCntr : unsigned(4 downto 0) := (others => '0');

    -- 23-bit shift registers for serdes
    signal sr_p2s : std_logic_vector(23 downto 0) := x"000000";
    signal sr_s2p : std_logic_vector(23 downto 0) := x"000000";

    -- states defined in Hints document
    type command_state_type is (
        idle, writeAddr2d, doneStartup, readAddr00, captureIdAd, readAddr01, captureId1d,
        readAddr08, captureX, readAddr09, captureY, readAddr0A, captureZ );
    signal command_state: command_state_type;

    type spi_state_type is (
        idle, setCSlow, clkH, clkL, clkInc, chkCnt, setCShi, wait100);
    signal spi_state : spi_state_type;

begin
    
    -- Command FSM --
    -- cycle through startup, read IDs, x,y,z
    -- fsm from lab5 hints, following FSM template from slides
    Command_FSM : process (clk, reset)
    begin
        if reset = '1' then
            
            command_state <= idle;
            SPIstart <= '0';

        elsif rising_edge(clk) then

            SPIstart <= '0';

            case command_state is
                
                -- queue up start up command
                when idle =>
                    toSPIbytes <= x"0a2d02"; -- write 02 2d for power up
                    SPIstart <= '1';
                    command_state <= writeAddr2d;

                -- wait for SPI to finish
                when writeAddr2d =>
                    if (SPIdone = '1' ) then
                        command_state <= doneStartup;
                    end if;
                
                -- queue up ID_AD read
                when doneStartup =>
                    toSPIbytes <= x"0b0000";
                    SPIstart <= '1';
                    command_state <= readAddr00;

                -- wait for SPI to finish
                when readAddr00 =>
                    if (SPIdone = '1') then
                        command_state <= captureIdAd;
                    end if;
                
                -- queue up ID 1D read
                when captureIdAd =>
                    toSPIbytes <= x"0b0100";
                    SPIstart <= '1';
                    command_state <= readAddr01;
                    id_ad <= sr_s2p(7 downto 0);

                -- wait for SPI to finish
                when readAddr01 =>
                    if (SPIdone = '1') then
                        command_state <= captureId1d;
                    end if;

                --queue up x read
                when captureId1d =>
                    toSPIbytes <= x"0b0800";
                    SPIstart <= '1';
                    command_state <= readAddr08;
                    id_1d <= sr_s2p(7 downto 0);
                
                --wait for SPI to finish
                when readAddr08 =>
                    if (SPIdone = '1') then 
                        command_state <= captureX;
                    end if;
                
                -- queue up y read
                when captureX =>
                    toSPIbytes <= x"0b0900";
                    SPIstart <= '1';
                    command_state <= readAddr09;
                    data_x <= sr_s2p(7 downto 0);
                
                --wait for SPI to finish
                when readAddr09 =>
                    if SPIdone = '1' then
                        command_state <= captureY;
                    end if;
                
                -- queue up Z read
                when captureY =>
                    toSPIbytes <= x"0b0a00";
                    SPIstart <= '1';
                    command_state <= readAddr0A;
                    data_y <= sr_s2p(7 downto 0);

                --wait for SPI to finish
                when readAddr0A =>
                    if SPIdone = '1' then
                        command_state <= captureZ;
                    end if;

                -- queue up ID_AD read
                when captureZ =>
                    toSPIbytes <= x"0b0000";
                    SPIstart <= '1';
                    command_state <= readAddr00;
                    data_z <= sr_s2p(7 downto 0);

            end case;
        end if;
    end process;

    -- SPI FSM --
    -- drive cs/sclk with appropriate timing 
    -- when triggered by SPIstart   
    SPI_FSM : process(clk, reset)


    begin
        if reset = '1' then
            spi_state <= idle;
            SPIdone <= '0';
            cs <= '1';
            sclk <= '0';
        elsif rising_edge(clk) then
            case spi_state is
                when idle =>
                    cs <= '1';
                    sclk <= '0';
                    SPIdone <= '0';
                    if SPIstart = '1' then
                        spi_state <= setCSlow;
                    else
                        spi_state <= idle;
                    end if;

                when setCSlow =>
                    cs <= '0'; -- enable the acl
            
                    -- start timer to ensure Css > 100 ns (150 here)
                    tim_start <='1';
                    tim_max <= to_unsigned(15,17);
                    if (tim_done = '1') then
                        spi_state <= clkH;
                    else 
                        spi_state <= setCSlow;
                    end if;

                when clkH =>
                    sclk <= '1';

                    -- spend 50 cycles high
                    tim_start <= '1';
                    tim_max <= to_unsigned(49,17);
                    if(tim_done = '1') then
                        spi_state <= clkL;
                        tim_start <= '0';
                    else
                        spi_state <= clkH;
                    end if;

                when clkL =>
                    sclk <= '0';

                    -- spend 50 cycles low
                    tim_start <= '1';
                    tim_max <= to_unsigned(47,17);
                    if(tim_done = '1') then
                        spi_state <= clkInc;
                        tim_start <= '0';
                    else 
                        spi_state <= clkL;
                    end if;

                when clkInc =>
                    spi_state <= chkCnt;
                when chkCnt =>

                    if sclkCntr >= 24 then
                        spi_state <= setCShi;
                    else
                        spi_state <= clkH;
                    end if;

                when setCShi =>
                    cs <= '1';
                    spi_state <= wait100;
                when wait100 =>
                    tim_start <= '1';
                    tim_max <= to_unsigned(100,17); -- 100 ms, shorter for sim;
                    if (tim_done = '1') then
                        spi_state <= idle;
                        tim_start <= '0';
                        SPIdone <= '1';
                    else 
                        spi_state <= wait100;
                        cs <= '1';
                    end if;
                    
            end case;
        end if;
    end process;

    -- timer process from slides
    timerFSM : process (clk, reset)
    begin
        if (reset = '1') then 
            tim_cntr <= (others => '0');
        elsif rising_edge(clk) then
            if (tim_start = '1') then
                if (tim_cntr < tim_max) then 
                    tim_cntr <= tim_cntr + 1;
                else 
                    tim_cntr <= (others => '0');
                end if;
            else
                tim_cntr <= (others => '0');
            end if;
        end if;
    end process;
    tim_done <= '1' when tim_cntr = tim_max else '0';


    -- counter for sclk to ensure only 24 cycles per protocol
    sclkCnt : process (clk, reset)
    begin
        if reset = '1' then
            -- reset
            sclkCntr <= (others => '0');
        elsif rising_edge(clk) then
            if (spi_state = clkInc) then
                sclkCntr <= sclkCntr + 1;
            elsif spi_state = wait100 then
                sclkCntr <= (others => '0');
            end if;
        end if;

    end process;

    -- shift "toSPIbytes" onto MOSI at appropriate times per SPI protocol
    parallel2serial : process (clk, reset)
    begin
        if reset = '1' then
            sr_p2s <= x"000000";
            mosi <= '0';
        elsif rising_edge(clk) then
            if SPIstart = '1' then
               sr_p2s <= toSPIbytes;
            elsif spi_state = clkH and tim_done = '1' then 
               mosi <= sr_p2s(23);
               sr_p2s(23 downto 1) <= sr_p2s(22 downto 0);
               sr_p2s(0) <= sr_p2s(23);
            end if;
        end if;
    end process;

    -- read MISO into data registers depending on FSM states
    serial2parallel : process (clk, reset)
    begin
        if reset = '1' then
           sr_s2p <= x"000000";
        elsif rising_edge(clk) then
            -- shift in MISO on SCLK
            if spi_state = chkCnt and sclkCntr <= 24 then
                sr_s2p(23 downto 1) <= sr_s2p(22 downto 0);
                sr_s2p(0) <= miso;
            end if;
        end if; 
    end process;
end arch;




