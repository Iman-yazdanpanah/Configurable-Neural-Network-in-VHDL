
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fixed_mac_tb is
end fixed_mac_tb;

architecture Simulation of fixed_mac_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant ACC_WIDTH  : positive := 32;

    signal a           : signed(DATA_WIDTH - 1 downto 0)
                        := (others => '0');
    signal b           : signed(DATA_WIDTH - 1 downto 0)
                        := (others => '0');
    signal accumulator : signed(ACC_WIDTH - 1 downto 0)
                        := (others => '0');
    signal result      : signed(ACC_WIDTH - 1 downto 0);

begin

    DUT : entity work.fixed_mac
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            ACC_WIDTH  => ACC_WIDTH
        )
        port map (
            a           => a,
            b           => b,
            accumulator => accumulator,
            result      => result
        );

    stimulus : process
    begin

        -- Test 1: 1.5 * 2.0 + 0 = 3.0
        -- Stored product: 768 * 1024 / 512 = 1536.
        a <= to_signed(768, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        accumulator <= to_signed(0, ACC_WIDTH);
        wait for 10 ns;

        assert result = to_signed(1536, ACC_WIDTH)
            report "Test 1 failed: basic MAC"
            severity error;

        -- Test 2: 1.0 * 2.0 + 3.0 = 5.0
        -- Stored result: 512 * 1024 / 512 + 1536 = 2560.
        a <= to_signed(512, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        accumulator <= to_signed(1536, ACC_WIDTH);
        wait for 10 ns;

        assert result = to_signed(2560, ACC_WIDTH)
            report "Test 2 failed: accumulation"
            severity error;

        -- Test 3: -1.5 * 2.0 + 1.0 = -2.0
        a <= to_signed(-768, DATA_WIDTH);
        b <= to_signed(1024, DATA_WIDTH);
        accumulator <= to_signed(512, ACC_WIDTH);
        wait for 10 ns;

        assert result = to_signed(-1024, ACC_WIDTH)
            report "Test 3 failed: negative MAC"
            severity error;

        report "All fixed_mac tests completed successfully."
            severity note;

        wait;
    end process;

end Simulation;
