
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity layer_gradients_tb is
end layer_gradients_tb;

architecture test of layer_gradients_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural := 9;
    constant N_INPUTS   : positive := 2;
    constant N_NEURONS  : positive := 2;
    constant GRAD_WIDTH : positive := 32;

    signal layer_inputs : STD_LOGIC_VECTOR(31 downto 0)
        := (others => '0');

    signal neuron_deltas : STD_LOGIC_VECTOR(31 downto 0)
        := (others => '0');

    signal weight_gradients : STD_LOGIC_VECTOR(127 downto 0);
    signal bias_gradients : STD_LOGIC_VECTOR(63 downto 0);

begin

    uut : entity work.layer_gradients
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            N_NEURONS  => N_NEURONS,
            GRAD_WIDTH => GRAD_WIDTH
        )
        port map (
            layer_inputs     => layer_inputs,
            neuron_deltas    => neuron_deltas,
            weight_gradients => weight_gradients,
            bias_gradients   => bias_gradients
        );

    stimulus : process
    begin
        -- Inputs: x0 = 1.0, x1 = 2.0
        layer_inputs(15 downto 0)  <= std_logic_vector(to_signed(512, 16));
        layer_inputs(31 downto 16) <= std_logic_vector(to_signed(1024, 16));
        
        -- Neuron 0 delta = 4.0; neuron 1 delta = -2.0
        neuron_deltas(15 downto 0)  <= std_logic_vector(to_signed(2048, 16));
        neuron_deltas(31 downto 16) <= std_logic_vector(to_signed(-1024, 16));

        wait for 10 ns;

        -- Neuron 0: gradients [4.0, 8.0], bias = 4.0
        assert signed(weight_gradients(31 downto 0)) = to_signed(2048, 32)
            report "TEST 1 FAILED: neuron 0, weight 0"
            severity error;

        assert signed(weight_gradients(63 downto 32)) = to_signed(4096, 32)
            report "TEST 2 FAILED: neuron 0, weight 1"
            severity error;

        assert signed(bias_gradients(31 downto 0)) = to_signed(2048, 32)
            report "TEST 3 FAILED: neuron 0 bias"
            severity error;

        report "TESTS 1-3 PASSED: Neuron 0 gradients"
            severity note;

        -- Neuron 1: gradients [-2.0, -4.0], bias = -2.0
        assert signed(weight_gradients(95 downto 64)) = to_signed(-1024, 32)
            report "TEST 4 FAILED: neuron 1, weight 0"
            severity error;

        assert signed(weight_gradients(127 downto 96)) = to_signed(-2048, 32)
            report "TEST 5 FAILED: neuron 1, weight 1"
            severity error;

        assert signed(bias_gradients(63 downto 32)) = to_signed(-1024, 32)
            report "TEST 6 FAILED: neuron 1 bias"
            severity error;

        report "TESTS 4-6 PASSED: Neuron 1 gradients"
            severity note;

        -- Check that zero deltas produce zero gradients.
        neuron_deltas <= (others => '0');
        wait for 10 ns;

        assert signed(weight_gradients) = to_signed(0, 128)
            report "TEST 7 FAILED: zero-delta weight gradients"
            severity error;

        assert signed(bias_gradients) = to_signed(0, 64)
            report "TEST 8 FAILED: zero-delta bias gradients"
            severity error;

        report "TEST 7 PASSED: Zero deltas"
            severity note;

        report "ALL LAYER GRADIENT TESTS PASSED"
            severity note;

        wait;
    end process;

end test;
