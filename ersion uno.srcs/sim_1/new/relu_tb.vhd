
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simulation-only testbench for ReLU.

entity relu_tb is
end relu_tb;

architecture Simulation of relu_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;

    signal x      : signed(DATA_WIDTH - 1 downto 0)
                    := (others => '0');
    signal result : signed(DATA_WIDTH - 1 downto 0);

begin

    -- Instantiate our ReLU component.
    DUT : entity work.relu
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS
        )
        port map (
            x      => x,
            result => result
        );

    stimulus : process
    begin

        -- Test 1: ReLU(1.5) = 1.5
        -- With 9 fractional bits, 1.5 is stored as 768.
        x <= to_signed(768, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(768, DATA_WIDTH)
            report "Test 1 failed: positive input"
            severity error;

        -- Test 2: ReLU(-1.5) = 0
        x <= to_signed(-768, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(0, DATA_WIDTH)
            report "Test 2 failed: negative input"
            severity error;

        -- Test 3: ReLU(0) = 0
        x <= to_signed(0, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(0, DATA_WIDTH)
            report "Test 3 failed: zero input"
            severity error;

        -- Test 4: ReLU(0.5) = 0.5
        x <= to_signed(256, DATA_WIDTH);
        wait for 10 ns;
        assert result = to_signed(256, DATA_WIDTH)
            report "Test 4 failed: fractional input"
            severity error;

        report "All ReLU tests completed successfully."
            severity note;

        wait;
    end process;

end Simulation;
