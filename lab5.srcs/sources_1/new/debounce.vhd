----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/02/2022 09:24:57 PM
-- Design Name: 
-- Module Name: debounce - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity debounce is
--  Port ( );
    Port (
        clk : in std_logic;
        rst : in std_logic;
        button_state : in std_logic;
        debounced : out std_logic
    );
end debounce;

architecture arch of debounce is

    -- clocked at 100MHz, (100e6 / 10) ticks is 100 ms --> 24 bits
    signal count : unsigned(23 downto 0) := (others => '0');

    -- store last val and current val
    signal output : std_logic_vector(1 downto 0) := "00";

begin
        -- debounce signal generator, 1 cycle pulse if held for 100 ms
        process (clk, rst)
        begin
            if (rst = '1') then
                debounced <= '0';
                count <= (others => '0');
            elsif (rising_edge(clk)) then

                -- do the debounce stuff
                output(1) <= output(0);

                -- if button currently pressed, uptick
                if (button_state = '1') then
                    -- debounce block for 100 ms from slides
                    if (count < 10000000) then
                        output(0) <= '0';
                        count <= count  + 1;
                    else 
                    -- it is above threshold, so consider it debounced, shift in 1
                        output(0) <= '1';
                    end if;
                else 
                    -- no button press, keep counter at zero and shift in 0
                    output(0) <= '0';
                    count <= (others => '0');
                end if;   

                -- output pulse if in transition, else 0
                if (output(0) = '1' and output(1) = '0') then
                    debounced <= '1';
                else 
                    debounced <= '0';
                end if;
              
            end if;
        end process;
    
end arch;
