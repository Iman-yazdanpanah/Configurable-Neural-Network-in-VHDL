
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity minmax_scaler_tb is
end minmax_scaler_tb;

architecture Behavioral of minmax_scaler_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;

    -- With 9 fractional bits, multiply real values by 512.
    signal x     : SIGNED(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal x_min : SIGNED(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal x_max : SIGNED(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal y     : SIGNED(DATA_WIDTH - 1 downto 0);

begin

    -- Instantiate the scaler.
    uut : entity work.minmax_scaler
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS
        )
        port map (
            x     => x,
            x_min => x_min,
            x_max => x_max,
            y     => y
        );

    stimulus : process
    begin

        -- Use the real input range [10, 30].
        -- Stored values: 10*512 = 5120; 30*512 = 15360.
        x_min <= to_signed(5120, DATA_WIDTH);
        x_max <= to_signed(15360, DATA_WIDTH);

        --------------------------------------------------
        -- TEST 1: minimum maps to -1.0
        --------------------------------------------------
        x <= to_signed(5120, DATA_WIDTH);
        wait for 10 ns;

        assert y = to_signed(-512, DATA_WIDTH)
            report "TEST 1 FAILED: expected -1.0 (-512)"
            severity error;

        --------------------------------------------------
        -- TEST 2: midpoint maps to 0.0
        --------------------------------------------------
        x <= to_signed(10240, DATA_WIDTH);
        wait for 10 ns;

        assert y = to_signed(0, DATA_WIDTH)
            report "TEST 2 FAILED: expected 0.0"
            severity error;

        --------------------------------------------------
        -- TEST 3: maximum maps to +1.0
        --------------------------------------------------
        x <= to_signed(15360, DATA_WIDTH);
        wait for 10 ns;

        assert y = to_signed(512, DATA_WIDTH)
            report "TEST 3 FAILED: expected +1.0 (512)"
            severity error;

        --------------------------------------------------
        -- TEST 4: 15 maps to -0.5
        --------------------------------------------------
        x <= to_signed(7680, DATA_WIDTH);
        wait for 10 ns;

        assert y = to_signed(-256, DATA_WIDTH)
            report "TEST 4 FAILED: expected -0.5 (-256)"
            severity error;

        --------------------------------------------------
        -- TEST 5: 25 maps to +0.5
        --------------------------------------------------
        x <= to_signed(12800, DATA_WIDTH);
        wait for 10 ns;

        assert y = to_signed(256, DATA_WIDTH)
            report "TEST 5 FAILED: expected +0.5 (256)"
            severity error;

        --------------------------------------------------
        -- TEST 6: input above maximum is clamped to +1
        --------------------------------------------------
        x <= to_signed(20480, DATA_WIDTH); -- Real value 40
        wait for 10 ns;

        assert y = to_signed(512, DATA_WIDTH)
            report "TEST 6 FAILED: expected clamped +1.0"
            severity error;

        --------------------------------------------------
        -- TEST 7: equal minimum and maximum
        -- Must not divide by zero.
        --------------------------------------------------
        x_min <= to_signed(5120, DATA_WIDTH);
        x_max <= to_signed(5120, DATA_WIDTH);
        x     <= to_signed(5120, DATA_WIDTH);
        wait for 10 ns;

        assert y = to_signed(0, DATA_WIDTH)
            report "TEST 7 FAILED: expected zero for invalid range"
            severity error;

        report "All minmax_scaler tests completed successfully."
            severity note;

        wait;
    end process;

end Behavioral;
