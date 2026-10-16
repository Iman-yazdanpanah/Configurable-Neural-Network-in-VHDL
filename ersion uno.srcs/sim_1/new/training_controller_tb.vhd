library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity training_controller_tb is
end training_controller_tb;

architecture Behavioral of training_controller_tb is

    signal clk   : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '0';
    signal start : STD_LOGIC := '0';

    signal forward_done          : STD_LOGIC := '0';
    signal output_gradients_done : STD_LOGIC := '0';
    signal hidden_gradients_done : STD_LOGIC := '0';
    signal output_update_done    : STD_LOGIC := '0';
    signal hidden_update_done    : STD_LOGIC := '0';

    signal forward_start          : STD_LOGIC;
    signal output_gradients_start : STD_LOGIC;
    signal hidden_gradients_start : STD_LOGIC;
    signal output_update_start    : STD_LOGIC;
    signal hidden_update_start    : STD_LOGIC;

    signal busy : STD_LOGIC;
    signal done : STD_LOGIC;

    constant CLK_PERIOD : time := 10 ns;

begin

    clk <= not clk after CLK_PERIOD / 2;

    DUT: entity work.training_controller
        port map (
            clk => clk,
            reset => reset,
            start => start,

            forward_done => forward_done,
            output_gradients_done => output_gradients_done,
            hidden_gradients_done => hidden_gradients_done,
            output_update_done => output_update_done,
            hidden_update_done => hidden_update_done,

            forward_start => forward_start,
            output_gradients_start => output_gradients_start,
            hidden_gradients_start => hidden_gradients_start,
            output_update_start => output_update_start,
            hidden_update_start => hidden_update_start,

            busy => busy,
            done => done
        );

    stimulus: process
    begin
        -- TEST 1: Reset
        reset <= '1';
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;

        assert busy = '0' and done = '0'
            report "TEST 1 FAILED: Reset" severity failure;
        report "TEST 1 PASSED: Reset" severity note;

        -- Start training
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- TEST 2: Forward propagation
        wait until forward_start = '1';
        assert busy = '1'
            report "TEST 2 FAILED: Busy during forward" severity failure;
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        forward_done <= '1';
        wait until rising_edge(clk);
        forward_done <= '0';
        report "TEST 2 PASSED: Forward stage" severity note;

        -- TEST 3: Output gradients
        wait until output_gradients_start = '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        output_gradients_done <= '1';
        wait until rising_edge(clk);
        output_gradients_done <= '0';
        report "TEST 3 PASSED: Output gradients stage" severity note;

        -- TEST 4: Hidden gradients
        wait until hidden_gradients_start = '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        hidden_gradients_done <= '1';
        wait until rising_edge(clk);
        hidden_gradients_done <= '0';
        report "TEST 4 PASSED: Hidden gradients stage" severity note;

        -- TEST 5: Output parameter update
        wait until output_update_start = '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        output_update_done <= '1';
        wait until rising_edge(clk);
        output_update_done <= '0';
        report "TEST 5 PASSED: Output update stage" severity note;

        -- TEST 6: Hidden parameter update
        wait until hidden_update_start = '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        hidden_update_done <= '1';
        wait until rising_edge(clk);
        hidden_update_done <= '0';

        wait until done = '1';
        assert busy = '0'
            report "TEST 6 FAILED: Busy should be low when finished"
            severity failure;

        report "TEST 6 PASSED: Hidden update stage" severity note;
        report "ALL TRAINING CONTROLLER TESTS PASSED" severity note;

        wait;
    end process;

end Behavioral;