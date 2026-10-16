
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_update is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        GRAD_WIDTH : positive := 32;
        N_WEIGHTS  : positive := 2;
        N_BIASES   : positive := 1
    );
    port (
        -- Current weights and their gradients
        weights : in STD_LOGIC_VECTOR(
            N_WEIGHTS * DATA_WIDTH - 1 downto 0
        );

        weight_gradients : in STD_LOGIC_VECTOR(
            N_WEIGHTS * GRAD_WIDTH - 1 downto 0
        );

        -- Current biases and their gradients
        biases : in STD_LOGIC_VECTOR(
            N_BIASES * DATA_WIDTH - 1 downto 0
        );

        bias_gradients : in STD_LOGIC_VECTOR(
            N_BIASES * GRAD_WIDTH - 1 downto 0
        );

        -- Learning rate in the same fixed-point format
        learning_rate : in SIGNED(DATA_WIDTH - 1 downto 0);

        -- Updated parameters
        updated_weights : out STD_LOGIC_VECTOR(
            N_WEIGHTS * DATA_WIDTH - 1 downto 0
        );

        updated_biases : out STD_LOGIC_VECTOR(
            N_BIASES * DATA_WIDTH - 1 downto 0
        )
    );
end parameter_update;

architecture Behavioral of parameter_update is

    -- Largest and smallest signed DATA_WIDTH values
    constant MAX_VALUE : SIGNED(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '0', others => '1');

    constant MIN_VALUE : SIGNED(DATA_WIDTH - 1 downto 0) :=
        (DATA_WIDTH - 1 => '1', others => '0');

    -- Product width: learning rate times gradient
    constant PROD_WIDTH : positive := DATA_WIDTH + GRAD_WIDTH;

begin

    process(
        weights, weight_gradients,
        biases, bias_gradients,
        learning_rate
    )
        variable old_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable gradient  : SIGNED(GRAD_WIDTH - 1 downto 0);

        variable full_product : SIGNED(PROD_WIDTH - 1 downto 0);
        variable scaled_gradient : SIGNED(PROD_WIDTH - 1 downto 0);

        variable updated_value : SIGNED(GRAD_WIDTH - 1 downto 0);
        variable weight_result : SIGNED(DATA_WIDTH - 1 downto 0);

        variable new_weights : STD_LOGIC_VECTOR(
            N_WEIGHTS * DATA_WIDTH - 1 downto 0
        );

        variable new_biases : STD_LOGIC_VECTOR(
            N_BIASES * DATA_WIDTH - 1 downto 0
        );

    begin

        -- Update each weight
        for i in 0 to N_WEIGHTS - 1 loop

            old_value := SIGNED(
                weights((i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH)
            );

            gradient := SIGNED(
                weight_gradients(
                    (i + 1) * GRAD_WIDTH - 1 downto i * GRAD_WIDTH
                )
            );

            -- Multiply learning rate by gradient.
            -- Q9 x Q9 produces Q18.
            full_product := learning_rate * gradient;

            -- Convert Q18 back to Q9.
            scaled_gradient := SHIFT_RIGHT(full_product, FRAC_BITS);

            -- Gradient descent: w_new = w_old - learning_rate * gradient
            updated_value :=
                RESIZE(old_value, GRAD_WIDTH)
                - RESIZE(scaled_gradient, GRAD_WIDTH);

            -- Saturate to the DATA_WIDTH signed range
            if updated_value > RESIZE(MAX_VALUE, GRAD_WIDTH) then
                weight_result := MAX_VALUE;

            elsif updated_value < RESIZE(MIN_VALUE, GRAD_WIDTH) then
                weight_result := MIN_VALUE;

            else
                weight_result := RESIZE(updated_value, DATA_WIDTH);
            end if;

            new_weights(
                (i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH
            ) := STD_LOGIC_VECTOR(weight_result);

        end loop;


        -- Update each bias using the same rule
        for i in 0 to N_BIASES - 1 loop

            old_value := SIGNED(
                biases((i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH)
            );

            gradient := SIGNED(
                bias_gradients(
                    (i + 1) * GRAD_WIDTH - 1 downto i * GRAD_WIDTH
                )
            );

            full_product := learning_rate * gradient;
            scaled_gradient := SHIFT_RIGHT(full_product, FRAC_BITS);

            updated_value :=
                RESIZE(old_value, GRAD_WIDTH)
                - RESIZE(scaled_gradient, GRAD_WIDTH);

            if updated_value > RESIZE(MAX_VALUE, GRAD_WIDTH) then
                weight_result := MAX_VALUE;

            elsif updated_value < RESIZE(MIN_VALUE, GRAD_WIDTH) then
                weight_result := MIN_VALUE;

            else
                weight_result := RESIZE(updated_value, DATA_WIDTH);
            end if;

            new_biases(
                (i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH
            ) := STD_LOGIC_VECTOR(weight_result);

        end loop;

        updated_weights <= new_weights;
        updated_biases  <= new_biases;

    end process;

end Behavioral;
