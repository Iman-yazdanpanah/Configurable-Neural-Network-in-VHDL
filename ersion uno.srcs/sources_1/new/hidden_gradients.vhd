
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hidden_gradients is
    generic (
        DATA_WIDTH  : positive := 16;
        FRAC_BITS   : natural  := 9;
        N_INPUTS    : positive := 2;
        N_HIDDEN    : positive := 2;
        N_OUTPUTS   : positive := 2;
        ACC_WIDTH   : positive := 40
    );
    port (
        inputs : in STD_LOGIC_VECTOR(
            N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        hidden_activations : in STD_LOGIC_VECTOR(
            N_HIDDEN * DATA_WIDTH - 1 downto 0
        );

        output_deltas : in STD_LOGIC_VECTOR(
            N_OUTPUTS * DATA_WIDTH - 1 downto 0
        );

        output_weights : in STD_LOGIC_VECTOR(
            N_OUTPUTS * N_HIDDEN * DATA_WIDTH - 1 downto 0
        );

        hidden_deltas : out STD_LOGIC_VECTOR(
            N_HIDDEN * DATA_WIDTH - 1 downto 0
        );

        weight_gradients : out STD_LOGIC_VECTOR(
            N_HIDDEN * N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        bias_gradients : out STD_LOGIC_VECTOR(
            N_HIDDEN * DATA_WIDTH - 1 downto 0
        )
    );
end hidden_gradients;

architecture Behavioral of hidden_gradients is

    function saturate (
        value : SIGNED(ACC_WIDTH - 1 downto 0)
    ) return SIGNED is
        variable result_value : SIGNED(DATA_WIDTH - 1 downto 0);
        variable max_value    : SIGNED(ACC_WIDTH - 1 downto 0);
        variable min_value    : SIGNED(ACC_WIDTH - 1 downto 0);
    begin
        max_value := to_signed(2**(DATA_WIDTH-1)-1, ACC_WIDTH);
        min_value := to_signed(-(2**(DATA_WIDTH-1)), ACC_WIDTH);

        if value > max_value then
            result_value := to_signed(
                2**(DATA_WIDTH-1)-1, DATA_WIDTH
            );
        elsif value < min_value then
            result_value := to_signed(
                -(2**(DATA_WIDTH-1)), DATA_WIDTH
            );
        else
            result_value := resize(value, DATA_WIDTH);
        end if;

        return result_value;
    end function;

begin

    process (
        inputs,
        hidden_activations,
        output_deltas,
        output_weights
    )
        variable hidden_delta_v : SIGNED(
            N_HIDDEN * DATA_WIDTH - 1 downto 0
        );

        variable weight_grad_v : SIGNED(
            N_HIDDEN * N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        variable bias_grad_v : SIGNED(
            N_HIDDEN * DATA_WIDTH - 1 downto 0
        );

        variable sum_v : SIGNED(ACC_WIDTH - 1 downto 0);
        variable delta_v : SIGNED(DATA_WIDTH - 1 downto 0);

        variable product_v : SIGNED(2 * DATA_WIDTH - 1 downto 0);

        variable input_v : SIGNED(DATA_WIDTH - 1 downto 0);
        variable activation_v : SIGNED(DATA_WIDTH - 1 downto 0);
        variable output_delta_v : SIGNED(DATA_WIDTH - 1 downto 0);
        variable output_weight_v : SIGNED(DATA_WIDTH - 1 downto 0);

        variable h : integer;
        variable o : integer;
        variable i : integer;
    begin
        hidden_delta_v := (others => '0');
        weight_grad_v  := (others => '0');
        bias_grad_v    := (others => '0');

        -- Calculate each hidden neuron's error signal.
        for h in 0 to N_HIDDEN - 1 loop
            sum_v := (others => '0');

            activation_v := signed(
                hidden_activations(
                    (h+1)*DATA_WIDTH-1 downto h*DATA_WIDTH
                )
            );

            -- Backpropagate through the output-layer weights.
            for o in 0 to N_OUTPUTS - 1 loop
                output_delta_v := signed(
                    output_deltas(
                        (o+1)*DATA_WIDTH-1 downto o*DATA_WIDTH
                    )
                );

                -- Output weights are stored output-neuron-major.
                output_weight_v := signed(
                    output_weights(
                        (o*N_HIDDEN+h+1)*DATA_WIDTH-1
                        downto (o*N_HIDDEN+h)*DATA_WIDTH
                    )
                );

                product_v := output_weight_v * output_delta_v;

                sum_v := sum_v + resize(
                    shift_right(product_v, FRAC_BITS),
                    ACC_WIDTH
                );
            end loop;

            -- ReLU derivative: zero when activation <= 0.
            if activation_v <= to_signed(0, DATA_WIDTH) then
                delta_v := (others => '0');
            else
                delta_v := saturate(sum_v);
            end if;

            hidden_delta_v(
                (h+1)*DATA_WIDTH-1 downto h*DATA_WIDTH
            ) := delta_v;

            -- Bias gradient equals the hidden error signal.
            bias_grad_v(
                (h+1)*DATA_WIDTH-1 downto h*DATA_WIDTH
            ) := delta_v;

            -- Weight gradient = hidden delta * layer input.
            for i in 0 to N_INPUTS - 1 loop
                input_v := signed(
                    inputs(
                        (i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH
                    )
                );

                product_v := delta_v * input_v;

                weight_grad_v(
                    (h*N_INPUTS+i+1)*DATA_WIDTH-1
                    downto (h*N_INPUTS+i)*DATA_WIDTH
                ) := saturate(
                    resize(
                        shift_right(product_v, FRAC_BITS),
                        ACC_WIDTH
                    )
                );
            end loop;
        end loop;

        hidden_deltas   <= STD_LOGIC_VECTOR(hidden_delta_v);
        weight_gradients <= STD_LOGIC_VECTOR(weight_grad_v);
        bias_gradients   <= STD_LOGIC_VECTOR(bias_grad_v);
    end process;

end Behavioral;
