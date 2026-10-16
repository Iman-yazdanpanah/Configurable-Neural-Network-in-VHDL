
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.nn_types.ALL;

entity dense_layer_memory_tb is
end dense_layer_memory_tb;

architecture Simulation of dense_layer_memory_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant N_INPUTS   : positive := 2;
    constant N_NEURONS  : positive := 2;
    constant N_WEIGHTS  : positive := N_INPUTS * N_NEURONS;

    signal clk   : STD_LOGIC := '0';
    signal reset : STD_LOGIC := '1';
    signal start : STD_LOGIC := '0';

    signal inputs : STD_LOGIC_VECTOR(
        N_INPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal weight_read_addr : integer range 0 to N_WEIGHTS - 1;
    signal weight_read_data : SIGNED(DATA_WIDTH - 1 downto 0);

    signal bias_read_addr : integer range 0 to N_NEURONS - 1;
    signal bias_read_data : SIGNED(DATA_WIDTH - 1 downto 0);

    signal outputs : STD_LOGIC_VECTOR(
        N_NEURONS * DATA_WIDTH - 1 downto 0
    );

    signal busy : STD_LOGIC;
    signal done : STD_LOGIC;

    -- Memory write controls, used to preload test parameters
    signal weight_write_enable : STD_LOGIC := '0';
    signal weight_write_addr : integer range 0 to N_WEIGHTS - 1 := 0;
    signal weight_write_data : SIGNED(DATA_WIDTH - 1 downto 0) := (others => '0');

    signal bias_write_enable : STD_LOGIC := '0';
    signal bias_write_addr : integer range 0 to N_NEURONS - 1 := 0;
    signal bias_write_data : SIGNED(DATA_WIDTH - 1 downto 0) := (others => '0');

begin

    clk <= not clk after 5 ns;

    ----------------------------------------------------------------
    -- Memory under test
    ----------------------------------------------------------------
    MEMORY : entity work.parameter_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_NEURONS
        )
        port map (
            clk => clk,

            weight_write_enable => weight_write_enable,
            weight_write_addr   => weight_write_addr,
            weight_write_data   => weight_write_data,
            weight_read_addr    => weight_read_addr,
            weight_read_data    => weight_read_data,

            bias_write_enable => bias_write_enable,
            bias_write_addr   => bias_write_addr,
            bias_write_data   => bias_write_data,
            bias_read_addr    => bias_read_addr,
            bias_read_data    => bias_read_data
        );

    ----------------------------------------------------------------
    -- Memory-to-dense-layer module
    ----------------------------------------------------------------
    DUT : entity work.dense_layer_memory
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            N_NEURONS  => N_NEURONS,
            ACC_WIDTH  => 40,
            ACTIVATION => RELU
        )
        port map (
            clk => clk,
            reset => reset,
            start => start,

            inputs => inputs,

            weight_read_addr => weight_read_addr,
            weight_read_data => weight_read_data,

            bias_read_addr => bias_read_addr,
            bias_read_data => bias_read_data,

            outputs => outputs,
            busy => busy,
            done => done
        );

    ----------------------------------------------------------------
    -- Test procedure
    ----------------------------------------------------------------
    stimulus : process
    begin

        -- Reset
        reset <= '1';
        wait for 20 ns;
        wait until falling_edge(clk);
        reset <= '0';

        ----------------------------------------------------------------
        -- Preload weights:
        -- Address 0:  1.0 =  512
        -- Address 1:  2.0 = 1024
        -- Address 2: -1.0 = -512
        -- Address 3:  1.0 =  512
        ----------------------------------------------------------------
        for i in 0 to N_WEIGHTS - 1 loop
            wait until falling_edge(clk);

            weight_write_enable <= '1';
            weight_write_addr <= i;

            case i is
                when 0 =>
                    weight_write_data <= to_signed(512, DATA_WIDTH);
                when 1 =>
                    weight_write_data <= to_signed(1024, DATA_WIDTH);
                when 2 =>
                    weight_write_data <= to_signed(-512, DATA_WIDTH);
                when others =>
                    weight_write_data <= to_signed(512, DATA_WIDTH);
            end case;

            wait until rising_edge(clk);
        end loop;

        wait until falling_edge(clk);
        weight_write_enable <= '0';

        -- Both biases are zero.
        for i in 0 to N_NEURONS - 1 loop
            wait until falling_edge(clk);

            bias_write_enable <= '1';
            bias_write_addr <= i;
            bias_write_data <= to_signed(0, DATA_WIDTH);

            wait until rising_edge(clk);
        end loop;

        wait until falling_edge(clk);
        bias_write_enable <= '0';

        report "TEST 1 PASSED: Parameters loaded into memory"
            severity note;

        ----------------------------------------------------------------
        -- Inputs: input 0 = 1.0, input 1 = 2.0
        -- Lowest DATA_WIDTH bits hold input 0.
        ----------------------------------------------------------------
        inputs(DATA_WIDTH - 1 downto 0) <=
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        inputs(2 * DATA_WIDTH - 1 downto DATA_WIDTH) <=
            STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH));

        ----------------------------------------------------------------
        -- Start parameter loading and inference
        ----------------------------------------------------------------
        wait until falling_edge(clk);
        start <= '1';

        wait until rising_edge(clk);
        wait until falling_edge(clk);
        start <= '0';

        -- Wait for the parameters to be loaded.
        for i in 0 to 30 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            exit when done = '1';
        end loop;

        assert done = '1'
            report "TEST FAILED: Parameter loading timed out"
            severity failure;

        assert busy = '0'
            report "TEST FAILED: Busy remains asserted"
            severity failure;

        report "TEST 2 PASSED: Parameters read from memory"
            severity note;

        ----------------------------------------------------------------
        -- Check neuron 0: 1*1 + 2*2 = 5
        ----------------------------------------------------------------
        assert signed(outputs(DATA_WIDTH - 1 downto 0)) =
               to_signed(2560, DATA_WIDTH)
            report "TEST FAILED: Neuron 0 expected 5.0"
            severity failure;

        report "TEST 3 PASSED: Neuron 0 output = 5.0"
            severity note;

        ----------------------------------------------------------------
        -- Check neuron 1: (-1)*1 + 1*2 = 1
        ----------------------------------------------------------------
        assert signed(outputs(2 * DATA_WIDTH - 1 downto DATA_WIDTH)) =
               to_signed(512, DATA_WIDTH)
            report "TEST FAILED: Neuron 1 expected 1.0"
            severity failure;

        report "TEST 4 PASSED: Neuron 1 output = 1.0"
            severity note;

        report "ALL DENSE LAYER MEMORY TESTS PASSED"
            severity note;

        wait;
    end process;

end Simulation;
