
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.all;

entity dense_layer is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        N_INPUTS   : positive := 2;
        N_NEURONS  : positive := 3;
        ACC_WIDTH  : positive := 40;
        ACTIVATION : activation_t := RELU
    );
    port (
        -- All input values packed into one vector.
        -- Input 0 occupies the lowest DATA_WIDTH bits.
        inputs : in STD_LOGIC_VECTOR(
            N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        -- Each neuron's complete group of weights is packed
        -- together. Neuron 0's weights occupy the lowest bits.
        weights : in STD_LOGIC_VECTOR(
            N_NEURONS * N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        -- One bias for each neuron.
        biases : in STD_LOGIC_VECTOR(
            N_NEURONS * DATA_WIDTH - 1 downto 0
        );

        -- One output value per neuron.
        outputs : out STD_LOGIC_VECTOR(
            N_NEURONS * DATA_WIDTH - 1 downto 0
        )
    );
end dense_layer;

architecture Behavioral of dense_layer is

    -- The neuron component has SIGNED outputs.
    -- This signal collects all neuron outputs.
    signal neuron_outputs : SIGNED(
        N_NEURONS * DATA_WIDTH - 1 downto 0
    );

begin

    -- Convert the packed signed output signal to a logic vector.
    outputs <= STD_LOGIC_VECTOR(neuron_outputs);

    -- Generate one neuron for each output.
    neuron_generation : for i in 0 to N_NEURONS - 1 generate

        neuron_instance : entity work.neuron
            generic map (
                DATA_WIDTH => DATA_WIDTH,
                FRAC_BITS  => FRAC_BITS,
                N_INPUTS   => N_INPUTS,
                ACC_WIDTH  => ACC_WIDTH,
                ACTIVATION => ACTIVATION
            )
            port map (
                -- Every neuron receives the same inputs.
                inputs => inputs,

                -- Select the weight group belonging to neuron i.
                weights => weights(
                    (i + 1) * N_INPUTS * DATA_WIDTH - 1
                    downto i * N_INPUTS * DATA_WIDTH
                ),

                -- Select the bias belonging to neuron i.
                bias => SIGNED(biases(
                    (i + 1) * DATA_WIDTH - 1
                    downto i * DATA_WIDTH
                )),

                -- Give each neuron its own output slice.
                result => neuron_outputs(
                    (i + 1) * DATA_WIDTH - 1
                    downto i * DATA_WIDTH
                )
            );

    end generate neuron_generation;

end Behavioral;
