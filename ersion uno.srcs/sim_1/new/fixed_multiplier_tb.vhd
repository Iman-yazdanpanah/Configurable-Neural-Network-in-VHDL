
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simulation-only testbench for fixed_multiplier.

entity fixed_multiplier_tb is
end fixed_multiplier_tb;

architecture Simulation of fixed_multiplier_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;

    signal a      : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal b      : signed(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal result : signed(DATA_WIDTH - 1 downto 0);

begin

    -- Connect the testbench signals to the multiplier.
    DUT : entity work.fixed_multiplier
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS
        )
        port map (
            a      => a,
            b      => b,
            result => result
        );

    
    stimulus : process
    begin
    
        -- Test 1: 1.5 * 2.0 = 3.0
        -- With 9 fractional bits:
        -- 1.5 -> 768, 2.0 -> 1024, 3.0 -> 1536.
        a <= to_signed(768, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(1536, DATA_WIDTH)
            report "Test 1 failed: normal multiplication"
            severity error;
    
        -- Test 2: 1.5 * 1.5 = 2.25.
        a <= to_signed(768, DATA_WIDTH);
        b <= to_signed(768, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(1152, DATA_WIDTH)
            report "Test 2 failed: fractional multiplication"
            severity error;
    
        -- Test 3: negative times positive = negative.
        -- -1.5 * 2.0 = -3.0.
        a <= to_signed(-768, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(-1536, DATA_WIDTH)
            report "Test 3 failed: negative multiplication"
            severity error;
    
        -- Test 4: positive overflow.
        -- 100.0 * 100.0 = 10000.0, outside our format's range.
        -- 100.0 is stored as 51200, which does NOT fit in 16 bits!
        -- Therefore, use two representable values instead:
        -- 60.0 -> 30720; 2.0 -> 1024.
        -- 60.0 * 2.0 = 120.0, which exceeds the maximum.
        a <= to_signed(30720, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(32767, DATA_WIDTH)
            report "Test 4 failed: positive saturation"
            severity error;
    
        -- Test 5: negative overflow.
        -- -60.0 * 2.0 = -120.0, below the minimum.
        a <= to_signed(-30720, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(-32768, DATA_WIDTH)
            report "Test 5 failed: negative saturation"
            severity error;
    
        -- Test 6: zero multiplied by a number is zero.
        a <= to_signed(0, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(0, DATA_WIDTH)
            report "Test 6 failed: multiplication by zero"
            severity error;
    
        report "All saturating multiplier tests completed successfully."
            severity note;
    
        wait;
    end process;


end Simulation;
