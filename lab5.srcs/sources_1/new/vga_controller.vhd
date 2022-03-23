----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/25/2022 03:29:34 PM
-- Design Name: 
-- Module Name: vga_controller - Behavioral
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

entity vga_controller is
--  Port ( );
    Port (
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        pulse25 : in std_logic;

        X : in unsigned(7 downto 0);
        Y : in unsigned(7 downto 0);

        HS : out std_logic;
        VS : out std_logic;
        RED : out std_logic_vector(3 downto 0);
        GRN : out std_logic_vector(3 downto 0);
        BLU : out std_logic_vector(3 downto 0)
    );
end vga_controller;

architecture arch of vga_controller is

    -- color definitions
    constant blue : std_logic_vector(11 downto 0) := x"20d";
    constant green : std_logic_vector(11 downto 0) := x"042";
    constant red_block : std_logic_vector(11 downto 0) := x"b16";

    -- horizontal 10 bit counter
    signal hcnt : unsigned(9 downto 0);
    signal px : unsigned(9 downto 0); -- capture pixel offset for simpler comparisons

    -- vertical 10 bit counter
    signal vcnt : unsigned(9 downto 0);
    signal py : unsigned(9 downto 0); -- capture pixel offset for simpler comparisons

    -- 12-bit color data
    signal color : std_logic_vector(11 downto 0);
    signal start_color : std_logic_vector(11 downto 0);

begin

    -- HSYNC
    process (clk, rst)
    begin
        if (rst = '1') then
            -- shut it down!
            hcnt <= (others => '0');
            vcnt <= (others => '0');

            HS <= '0';
            RED <= x"0";
            GRN <= x"0";
            BLU <= x"0"; 
            VS <= '0';

        elsif (rising_edge(clk)) then

            -- pulse-enabled counter
            if (pulse25 = '1') then
                hcnt <= hcnt + 1;

                -- HSYNC if tpw has passed (3.84 us = 96 ticks)
                if (hcnt < 96) then
                    HS <= '0';
                elsif (hcnt = 96) then --pulse to trigger vertical count
                    HS <= '1';
                elsif (hcnt = 99) then -- add a delay between onset of HS/VS
                    vcnt <= vcnt + 1;
                end if;

                if (vcnt < 519 ) then
                    VS <= '1';
                elsif (vcnt = 519) then
                    VS <= '0';
                end if;

                -- data if between porches and valid line (not in vertical retrace), 
                -- else zeros
                if (hcnt > 144 and hcnt < 784 and vcnt > 31 and vcnt < 511) then
                    -- current pixel index
                    px <= hcnt-145;
                    py <= vcnt-32;

                    -- 9 downto 5 for x,y index 
                    if (px(9 downto 5) = X and py(9 downto 5) = Y) then
                        color <= red_block;
                    -- bit 5 in counters should tell colors otherwise
                    elsif (px(5) = '1') then
                        if (py(5) = '1')then 
                            color <= blue;
                        else 
                            color <= green;
                        end if;
                    else 
                        if (py(5) = '1')then 
                            color <= green;
                        else 
                            color <= blue;
                        end if;
                    end if;

                    RED <= color(11 downto 8);
                    GRN <= color(7 downto 4);
                    BLU <= color(3 downto 0);

                else 
                    RED <= x"0";
                    GRN <= x"0";
                    BLU <= x"0";
                end if;

            end if;

            -- reset counters at max values
            if (hcnt > 800) then
                HS <= '0';
                hcnt <= (others => '0');
            end if;

            if (vcnt > 521) then
                VS <= '1';
                vcnt <= (others => '0');
            end if;


        end if;
    end process;

end arch;
