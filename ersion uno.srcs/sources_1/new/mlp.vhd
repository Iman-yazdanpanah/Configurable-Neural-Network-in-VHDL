
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.nn_types.all;

entity mlp is
    generic (
        DATA_WIDTH     : positive := 16;
        FRAC_BITS      : natural  := 9;
        N_INPUTS       : positive := 2;
        HIDDEN_NEURONS : positive := 3;
        OUTPUT_NEURONS : positive := 2;
        ACC_WIDTH      : positive := 40
    );

    port (
        -- Original input features
        inputs : in STD_LOGIC_VECTOR(
            N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        -- Hidden-layer parameters
        hidden_weights : in STD_LOGIC_VECTOR(
            HIDDEN_NEURONS * N_INPUTS * DATA_WIDTH - 1 downto 0
        );
        hidden_biases : in STD_LOGIC_VECTOR(
            HIDDEN_NEURONS * DATA_WIDTH - 1 downto 0
        );

        -- Output-layer parameters
        output_weights : in STD_LOGIC_VECTOR(
            OUTPUT_NEURONS * HIDDEN_NEURONS * DATA_WIDTH - 1 downto 0
        );
        output_biases : in STD_LOGIC_VECTOR(
            OUTPUT_NEURONS * DATA_WIDTH - 1 downto 0
        );

        -- Final network predictions
        outputs : out STD_LOGIC_VECTOR(
            OUTPUT_NEURONS * DATA_WIDTH - 1 downto 0
        )
    );
end mlp;

architecture Behavioral of mlp is

    -- The hidden layer produces one DATA_WIDTH-bit value
    -- for each hidden neuron.
    signal hidden_outputs : STD_LOGIC_VECTOR(
        HIDDEN_NEURONS * DATA_WIDTH - 1 downto 0
    );

begin

    -- Stage 1: calculate the hidden layer using ReLU.
    hidden_layer : entity work.dense_layer
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            N_NEURONS  => HIDDEN_NEURONS,
            ACC_WIDTH  => ACC_WIDTH,
            ACTIVATION => RELU
        )
        port map (
            inputs  => inputs,
            weights => hidden_weights,
            biases  => hidden_biases,
            outputs => hidden_outputs
        );

    -- Stage 2: use the hidden-layer results as the
    -- inputs to the output layer.
    output_layer : entity work.dense_layer
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => HIDDEN_NEURONS,
            N_NEURONS  => OUTPUT_NEURONS,
            ACC_WIDTH  => ACC_WIDTH,
            ACTIVATION => LINEAR
        )
        port map (
            inputs  => hidden_outputs,
            weights => output_weights,
            biases  => output_biases,
            outputs => outputs
        );

end Behavioral;
