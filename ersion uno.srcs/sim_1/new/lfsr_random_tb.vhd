
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lfsr_random_tb is
end lfsr_random_tb;

architecture Behavioral of lfsr_random_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural := 9;

    signal clk : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '0';
    signal seed_load : STD_LOGIC := '0';
    signal seed : STD_LOGIC_VECTOR(15 downto 0) := x"ACE1";
    signal enable : STD_LOGIC := '0';

    signal random_value : SIGNED(DATA_WIDTH - 1 downto 0);

begin

    clk <= not clk after 5 ns;

    uut : entity work.lfsr_random
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS
        )
        port map (
            clk          => clk,
            reset        => reset,
            seed_load    => seed_load,
            seed         => seed,
            enable       => enable,
            random_value => random_value
        );

    stimulus : process
        variable first_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable second_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable third_value : SIGNED(DATA_WIDTH - 1 downto 0);
    begin

        ------------------------------------------------
        -- TEST 1: Reset and generate changing values
        ------------------------------------------------
        reset <= '1';
        wait for 12 ns;
        reset <= '0';

        wait until falling_edge(clk);

        enable <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;
        first_value := random_value;

        wait until rising_edge(clk);
        wait for 1 ns;
        second_value := random_value;

        wait until rising_edge(clk);
        wait for 1 ns;
        third_value := random_value;

        assert first_value /= second_value
            report "ERROR: First two random values are identical"
            severity failure;

        assert second_value /= third_value
            report "ERROR: Next two random values are identical"
            severity failure;

        report "TEST 1 PASSED: Generator advances."
            severity note;


        ------------------------------------------------
        -- TEST 2: Reload seed and reproduce first value
        ------------------------------------------------
        enable <= '0';
        seed <= x"ACE1";
        seed_load <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        seed_load <= '0';
        enable <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert random_value = first_value
            report "ERROR: Generator did not reproduce sequence"
            severity failure;

        report "TEST 2 PASSED: Seed reproduces sequence."
            severity note;


        ------------------------------------------------
        -- TEST 3: All-zero seed protection
        ------------------------------------------------
        enable <= '0';
        seed <= x"0000";
        seed_load <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        seed_load <= '0';
        enable <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert random_value /= to_signed(0, DATA_WIDTH)
            report "ERROR: Generator stuck at zero"
            severity failure;

        report "TEST 3 PASSED: Zero seed protection."
            severity note;

        report "ALL LFSR RANDOM GENERATOR TESTS PASSED."
            severity note;

        wait;
    end process;

end Behavioral;
