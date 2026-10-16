
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hidden_gradients_tb is
end hidden_gradients_tb;

architecture test of hidden_gradients_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural := 9;

    signal inputs : STD_LOGIC_VECTOR(31 downto 0);
    signal hidden_activations : STD_LOGIC_VECTOR(31 downto 0);
    signal output_deltas : STD_LOGIC_VECTOR(31 downto 0);
    signal output_weights : STD_LOGIC_VECTOR(63 downto 0);

    signal hidden_deltas : STD_LOGIC_VECTOR(31 downto 0);
    signal weight_gradients : STD_LOGIC_VECTOR(63 downto 0);
    signal bias_gradients : STD_LOGIC_VECTOR(31 downto 0);

begin

    uut : entity work.hidden_gradients
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => 2,
            N_HIDDEN   => 2,
            N_OUTPUTS  => 2,
            ACC_WIDTH  => 40
        )
        port map (
            inputs            => inputs,
            hidden_activations => hidden_activations,
            output_deltas     => output_deltas,
            output_weights    => output_weights,
            hidden_deltas     => hidden_deltas,
            weight_gradients  => weight_gradients,
            bias_gradients    => bias_gradients
        );

    stimulus : process
    begin
        -- TEST 1: Apply inputs [2.0, 3.0].
        inputs(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(1024, 16));
        inputs(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(1536, 16));
        
        -- Hidden activations [1.0, 0.0].
        hidden_activations(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(512, 16));
        hidden_activations(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(0, 16));
        
        -- Output deltas [1.0, 1.0].
        output_deltas(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(512, 16));
        output_deltas(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(512, 16));
        
        -- Output neuron 0 weights [2.0, 3.0].
        output_weights(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(1024, 16));
        output_weights(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(1536, 16));
        
        -- Output neuron 1 weights [1.0, 4.0].
        output_weights(47 downto 32) <= STD_LOGIC_VECTOR(to_signed(512, 16));
        output_weights(63 downto 48) <= STD_LOGIC_VECTOR(to_signed(2048, 16));

        wait for 10 ns;

        assert signed(hidden_deltas(15 downto 0)) = 1536
            report "TEST 1 FAILED: Hidden delta 0 should be 3.0"
            severity error;

        assert signed(hidden_deltas(31 downto 16)) = 0
            report "TEST 2 FAILED: ReLU should suppress hidden delta 1"
            severity error;

        report "TEST 1 PASSED: Hidden delta 0 = 3.0";
        report "TEST 2 PASSED: Inactive ReLU neuron delta = 0";

        -- TEST 3: Gradients for hidden neuron 0.
        assert signed(weight_gradients(15 downto 0)) = 3072
            report "TEST 3 FAILED: Gradient w00 should be 6.0"
            severity error;

        assert signed(weight_gradients(31 downto 16)) = 4608
            report "TEST 4 FAILED: Gradient w01 should be 9.0"
            severity error;

        -- TEST 4: Gradients for hidden neuron 1.
        assert signed(weight_gradients(47 downto 32)) = 0
            report "TEST 5 FAILED: Inactive neuron gradient should be 0"
            severity error;

        assert signed(weight_gradients(63 downto 48)) = 0
            report "TEST 6 FAILED: Inactive neuron gradient should be 0"
            severity error;

        report "TEST 3 PASSED: Active neuron weight gradients = 6.0, 9.0";
        report "TEST 4 PASSED: Inactive neuron weight gradients = 0";

        -- TEST 5: Bias gradients.
        assert signed(bias_gradients(15 downto 0)) = 1536
            report "TEST 7 FAILED: Bias gradient 0 should be 3.0"
            severity error;

        assert signed(bias_gradients(31 downto 16)) = 0
            report "TEST 8 FAILED: Bias gradient 1 should be 0"
            severity error;

        report "TEST 5 PASSED: Bias gradients = 3.0, 0.0";
        report "ALL HIDDEN GRADIENT TESTS PASSED";
        
        
        
        
        -- TEST 6: Negative output deltas.
        -- Output deltas = [-1.0, 0.0].
        output_deltas(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(-512, 16));
        output_deltas(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(0, 16));

        wait for 10 ns;

        -- Hidden neuron 0:
        -- output weight = 2.0, delta = -1.0
        -- hidden delta = 2.0 * (-1.0) = -2.0
        assert signed(hidden_deltas(15 downto 0)) = -1024
            report "TEST 6 FAILED: Hidden delta 0 should be -2.0"
            severity error;

        -- Hidden neuron 1 has activation 0.0, so ReLU derivative is zero.
        assert signed(hidden_deltas(31 downto 16)) = 0
            report "TEST 7 FAILED: Inactive ReLU neuron should remain zero"
            severity error;

        report "TEST 6 PASSED: Negative hidden delta = -2.0";
        report "TEST 7 PASSED: ReLU suppresses inactive neuron";

        -- TEST 8: Negative hidden weight gradients.
        -- Input 0 = 2.0; delta = -2.0 => gradient = -4.0.
        assert signed(weight_gradients(15 downto 0)) = -2048
            report "TEST 8 FAILED: Weight gradient should be -4.0"
            severity error;

        -- Input 1 = 3.0; delta = -2.0 => gradient = -6.0.
        assert signed(weight_gradients(31 downto 16)) = -3072
            report "TEST 9 FAILED: Weight gradient should be -6.0"
            severity error;

        report "TEST 8 PASSED: Negative weight gradient 0 = -4.0";
        report "TEST 9 PASSED: Negative weight gradient 1 = -6.0";

        -- TEST 10: Negative bias gradient.
        assert signed(bias_gradients(15 downto 0)) = -1024
            report "TEST 10 FAILED: Bias gradient should be -2.0"
            severity error;

        report "TEST 10 PASSED: Negative bias gradient = -2.0";

        -- TEST 11: Zero output deltas produce zero gradients.
        output_deltas(15 downto 0)  <= STD_LOGIC_VECTOR(to_signed(0, 16));
        output_deltas(31 downto 16) <= STD_LOGIC_VECTOR(to_signed(0, 16));

        wait for 10 ns;

        assert signed(hidden_deltas(15 downto 0)) = 0
            report "TEST 11 FAILED: Zero output deltas should produce zero hidden delta"
            severity error;

        assert signed(weight_gradients(31 downto 0)) = to_signed(0, 32)
            report "TEST 12 FAILED: Zero output deltas should produce zero gradients"
            severity error;

        report "TEST 11 PASSED: Zero deltas produce zero hidden errors";
        report "TEST 12 PASSED: Zero deltas produce zero weight gradients";

        wait;
    end process;

end test;
