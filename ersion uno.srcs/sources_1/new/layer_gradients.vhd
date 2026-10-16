
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity layer_gradients is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        N_INPUTS   : positive := 2;
        N_NEURONS  : positive := 2;
        GRAD_WIDTH : positive := 32
    );
    port (
        layer_inputs : in STD_LOGIC_VECTOR(
            N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        neuron_deltas : in STD_LOGIC_VECTOR(
            N_NEURONS * DATA_WIDTH - 1 downto 0
        );

        weight_gradients : out STD_LOGIC_VECTOR(
            N_NEURONS * N_INPUTS * GRAD_WIDTH - 1 downto 0
        );

        bias_gradients : out STD_LOGIC_VECTOR(
            N_NEURONS * GRAD_WIDTH - 1 downto 0
        )
    );
end layer_gradients;

architecture Behavioral of layer_gradients is

    constant PRODUCT_WIDTH : positive := 2 * DATA_WIDTH;

    function saturate_gradient(
        value : SIGNED(PRODUCT_WIDTH - 1 downto 0)
    ) return SIGNED is
        variable result_value : SIGNED(GRAD_WIDTH - 1 downto 0);
        variable max_value : SIGNED(PRODUCT_WIDTH - 1 downto 0);
        variable min_value : SIGNED(PRODUCT_WIDTH - 1 downto 0);
    begin
        max_value := (others => '1');
        max_value(PRODUCT_WIDTH - 1) := '0';

        min_value := (others => '0');
        min_value(PRODUCT_WIDTH - 1) := '1';

        -- Build limits for the destination gradient width.
        if GRAD_WIDTH < PRODUCT_WIDTH then
            max_value := shift_right(
                to_signed(1, PRODUCT_WIDTH), 1
            );
            max_value := shift_left(max_value, GRAD_WIDTH - 1);
            max_value := max_value - 1;

            min_value := -max_value - 1;
        else
            max_value := (others => '1');
            max_value(PRODUCT_WIDTH - 1) := '0';

            min_value := (others => '0');
            min_value(PRODUCT_WIDTH - 1) := '1';
        end if;

        if value > max_value then
            result_value := (others => '1');
            result_value(GRAD_WIDTH - 1) := '0';
        elsif value < min_value then
            result_value := (others => '0');
            result_value(GRAD_WIDTH - 1) := '1';
        else
            result_value := resize(value, GRAD_WIDTH);
        end if;

        return result_value;
    end function;

begin

    process(layer_inputs, neuron_deltas)
        variable input_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable delta_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable product_value : SIGNED(PRODUCT_WIDTH - 1 downto 0);
        variable scaled_product : SIGNED(PRODUCT_WIDTH - 1 downto 0);
        variable gradient_value : SIGNED(GRAD_WIDTH - 1 downto 0);

        variable weights_result : STD_LOGIC_VECTOR(
            N_NEURONS * N_INPUTS * GRAD_WIDTH - 1 downto 0
        );
        variable biases_result : STD_LOGIC_VECTOR(
            N_NEURONS * GRAD_WIDTH - 1 downto 0
        );

        variable weight_index : integer;
    begin
        weights_result := (others => '0');
        biases_result := (others => '0');

        for neuron_index in 0 to N_NEURONS - 1 loop

            delta_value := signed(
                neuron_deltas(
                    (neuron_index + 1) * DATA_WIDTH - 1
                    downto neuron_index * DATA_WIDTH
                )
            );

            -- dL/db = delta
            gradient_value := resize(delta_value, GRAD_WIDTH);

            biases_result(
                (neuron_index + 1) * GRAD_WIDTH - 1
                downto neuron_index * GRAD_WIDTH
            ) := std_logic_vector(gradient_value);

            for input_index in 0 to N_INPUTS - 1 loop

                input_value := signed(
                    layer_inputs(
                        (input_index + 1) * DATA_WIDTH - 1
                        downto input_index * DATA_WIDTH
                    )
                );

                -- Q9 * Q9 produces Q18.
                product_value := input_value * delta_value;

                -- Return the gradient to Q9.
                scaled_product := shift_right(
                    product_value, FRAC_BITS
                );

                gradient_value := saturate_gradient(scaled_product);

                -- Neuron-major ordering; input 0 is the lowest slice.
                weight_index :=
                    neuron_index * N_INPUTS + input_index;

                weights_result(
                    (weight_index + 1) * GRAD_WIDTH - 1
                    downto weight_index * GRAD_WIDTH
                ) := std_logic_vector(gradient_value);

            end loop;
        end loop;

        weight_gradients <= weights_result;
        bias_gradients <= biases_result;
    end process;

end Behavioral;
