----------------------------------------------------------------------------------
-- 
-- Accelerometer Testbench to verify Accel Controller for Lab 5
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_textio.all;
use IEEE.NUMERIC_STD.ALL;
use work.all;

entity accel_spi_rw_tb is
end entity accel_spi_rw_tb;

architecture sim of accel_spi_rw_tb is

	signal clk : std_logic;
	signal reset : std_logic;
	
	--SPI Control Signals
	signal ACL_CSN, ACL_MOSI, ACL_SCLK, ACL_MISO : std_logic;
	
	--Output from Model which denotes if Accel is enabled/powered up
	signal acl_enabled : std_logic;
	
	signal ID_AD, ID_1D, DATA_X, DATA_Y, DATA_Z  : STD_LOGIC_VECTOR(7 downto 0);

begin

	--100MHz clock
	process
	begin
		clk <= '0';
		wait for 5 ns;
		clk <= '1';
		wait for 5 ns;
	end process;
	
	--Main testbench process
	process
	begin
		reset <= '1';
		wait for 1 ns;
		
		assert  ACL_CSN = '1'
		report "Error: Reset condition should have ACL_CSN = '1'"
		severity failure;
		
		assert  ACL_SCLK = '0'
        report "Error: Reset condition should have ACL_SCLK = '0'"
        severity failure;
		
		wait for 100 ns;
		reset <= '0';
		
		--TODO: Add Verification for DATA_X, Y, Z, and ID_AD/1D
		--TODO: Verify acl_enabled goes high after initial write
		--			This can be done through the waveform viewer or by writing checks in the testbench
		wait;
	end process;

	-- ensure CS is low at least 100 ns before SCLK is driven
	-- ensure CS stays high for 20 ns before falling again
	-- ensure CS hold of 20 ns
	verify_CS : process
		variable CS_low : time;
		variable CS_high : time;
	begin
		-- Css
		wait until ACL_CSN'EVENT and ACL_CSN = '0';   
		CS_low := now;  
		wait until ACL_SCLK'EVENT and ACL_SCLK='1';   
		assert (now - CS_low >= 100 ns) report "CS setup time violation" severity warning;
		
		-- tCSD/tCSH
		wait until ACL_CSN'EVENT and ACL_CSN = '1';
		CS_high := now;
		assert (ACL_SCLK'stable(20 ns) and ACL_SCLK = '0') report "CS hold time violation" severity warning;
		wait until ACL_CSN'EVENT and ACL_CSN = '0';
		assert (now - CS_high >= 20 ns) report "CS disable time violation" severity warning;
	end process;

	-- measure up/down time of sclk, ensure frequency in valid range
	verify_sclk : process
		variable clkH : time;
		variable clkL : time;
	begin
		wait until ACL_SCLK'EVENT and ACL_SCLK='1'; -- clock goes high
		clkH := now;
		wait until ACL_SCLK'EVENT and ACL_SCLK='0';
		assert (now - clkH >= 50 ns) report "tHIGH < 50 ns clock high time violation" severity warning;
		clkL := now;
		wait until ACL_SCLK'EVENT and ACL_SCLK='1';
		assert (now - clkL >= 50 ns) report "tLOW  < 50 ns clock low time violation" severity warning;
		assert (now - clkH > 125 ns ) report "fclk > 8MHz clock frequency violation" severity warning;
		assert (now - clkH < 416 us) report "fclk < 2.4KHz clock frequency violation" severity warning;
	end process;

	-- ensure MOSI has been stable for tsu before sclk transition, and stays stable for hold time
	verify_mosi : process
		variable t_sample : time;
	begin
		wait until ACL_SCLK'EVENT and ACL_SCLK='1' and ACL_CSN = '0';
		assert (ACL_MOSI'stable(20 ns)) report "tsu < 20ns data setup time violation" severity warning;
		t_sample := now;
		wait until ACL_MOSI'EVENT;
		assert (now - t_sample >= 20 ns) report "thd < 20 ns data hold time violation" severity warning;
	end process;

	
	--ACL Model
	ACL_DUMMY : entity acl_model port map (
		rst => reset,
		ACL_CSN => ACL_CSN, 
		ACL_MOSI => ACL_MOSI,
		ACL_SCLK => ACL_SCLK,
		ACL_MISO => ACL_MISO,
		--- ACCEL VALUES ---
		X_VAL => x"12",
		Y_VAL => x"34",
		Z_VAL => x"56",
		acl_enabled => acl_enabled);
	
	--Unit under test
	ACEL_DUT : entity acl_spi_rw port map (
		clk => clk,
		reset =>  reset,
		--Values from Accel
		data_x => DATA_X,
		data_y => DATA_Y,
		data_z => DATA_Z,
		id_ad => ID_AD,
		id_1d => ID_1D,
		--SPI Signals
		cs => ACL_CSN,
		mosi => ACL_MOSI,
		sclk => ACL_SCLK,
		miso => ACL_MISO);

end sim;