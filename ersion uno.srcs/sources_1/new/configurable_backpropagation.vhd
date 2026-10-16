library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.nn_types.ALL;

entity configurable_backpropagation is
    generic (
        DATA_WIDTH  : positive := 16;
        FRAC_BITS   : natural  := 9;
        LAYER_SIZES : positive_array_t := (2, 4, 4, 2);
        ACC_WIDTH   : positive := 40;
        GRAD_WIDTH  : positive := 32
    );
    port (
        -- Activations of all layers, including the input layer.
        all_activations : in STD_LOGIC_VECTOR(
            network_activation_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
        );

        -- Expected output values.
        targets : in STD_LOGIC_VECTOR(
            LAYER_SIZES(LAYER_SIZES'high)*DATA_WIDTH-1 downto 0
        );

        -- All weights, packed layer by layer and neuron by neuron.
        all_weights : in STD_LOGIC_VECTOR(
            network_weight_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
        );

        -- Gradient order: all weights first, then all biases.
        gradients : out STD_LOGIC_VECTOR(
            network_parameter_count(LAYER_SIZES)*GRAD_WIDTH-1 downto 0
        );

        -- Debug: deltas packed like all_activations.
        -- Input-layer deltas are zero.
        all_deltas : out STD_LOGIC_VECTOR(
            network_activation_count(LAYER_SIZES)*DATA_WIDTH-1 downto 0
        )
    );
end entity configurable_backpropagation;


architecture Behavioral of configurable_backpropagation is

    constant LAYER_COUNT : positive := LAYER_SIZES'length;
    constant TOTAL_ACTIVATIONS : positive :=
        network_activation_count(LAYER_SIZES);
    constant TOTAL_WEIGHTS : positive :=
        network_weight_count(LAYER_SIZES);
    constant TOTAL_PARAMETERS : positive :=
        network_parameter_count(LAYER_SIZES);

    type data_array_t is array (natural range <>) of
        SIGNED(DATA_WIDTH-1 downto 0);

    type gradient_array_t is array (natural range <>) of
        SIGNED(GRAD_WIDTH-1 downto 0);


    -- Offset of a layer's first activation.
    function activation_offset(
        sizes : positive_array_t;
        layer_index : natural
    ) return natural is
        variable total : natural := 0;
    begin
        for k in 0 to layer_index-1 loop
            total := total + sizes(sizes'low+k);
        end loop;

        return total;
    end function;


    -- Offset of the first weight connecting layer_index to
    -- layer_index+1. Weights are destination-neuron-major.
    function weight_offset(
        sizes : positive_array_t;
        layer_index : natural
    ) return natural is
        variable total : natural := 0;
    begin
        for k in 0 to layer_index-1 loop
            total := total +
                sizes(sizes'low+k) * sizes(sizes'low+k+1);
        end loop;

        return total;
    end function;


    -- Offset of the first bias belonging to dense layer layer_index.
    function bias_offset(
        sizes : positive_array_t;
        layer_index : natural
    ) return natural is
        variable total : natural := 0;
    begin
        for k in 0 to layer_index-1 loop
            total := total + sizes(sizes'low+k+1);
        end loop;

        return total;
    end function;


    -- Saturate a wide signed value to DATA_WIDTH.
    function saturate_data(
        value : SIGNED(ACC_WIDTH-1 downto 0)
    ) return SIGNED is
        variable result_value : SIGNED(DATA_WIDTH-1 downto 0);
        variable max_value : SIGNED(ACC_WIDTH-1 downto 0);
        variable min_value : SIGNED(ACC_WIDTH-1 downto 0);
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

    assert LAYER_COUNT >= 2
        report "LAYER_SIZES must contain input and output layers"
        severity failure;


    BACKPROPAGATION : process(
        all_activations,
        targets,
        all_weights
    )
        variable activation_v : data_array_t(
            0 to TOTAL_ACTIVATIONS-1
        );

        variable delta_v : data_array_t(
            0 to TOTAL_ACTIVATIONS-1
        );

        variable weights_v : data_array_t(
            0 to TOTAL_WEIGHTS-1
        );

        variable gradient_v : gradient_array_t(
            0 to TOTAL_PARAMETERS-1
        );

        variable gradient_bus_v : STD_LOGIC_VECTOR(
            TOTAL_PARAMETERS*GRAD_WIDTH-1 downto 0
        );

        variable delta_bus_v : STD_LOGIC_VECTOR(
            TOTAL_ACTIVATIONS*DATA_WIDTH-1 downto 0
        );

        variable product_v : SIGNED(2*DATA_WIDTH-1 downto 0);
        variable sum_v : SIGNED(ACC_WIDTH-1 downto 0);
        variable error_v : SIGNED(ACC_WIDTH-1 downto 0);

        variable target_v : SIGNED(DATA_WIDTH-1 downto 0);
        variable delta_next_v : SIGNED(DATA_WIDTH-1 downto 0);

        variable act_start : natural;
        variable next_act_start : natural;
        variable weight_start : natural;
        variable bias_start : natural;

        variable input_count : positive;
        variable neuron_count : positive;

        variable p : natural;
        variable w_index : natural;
        variable b_index : natural;

    begin
        activation_v := (others => (others => '0'));
        delta_v := (others => (others => '0'));
        weights_v := (others => (others => '0'));
        gradient_v := (others => (others => '0'));

        gradient_bus_v := (others => '0');
        delta_bus_v := (others => '0');

        ------------------------------------------------------------
        -- Unpack all activations and weights.
        ------------------------------------------------------------
        for p in 0 to TOTAL_ACTIVATIONS-1 loop
            activation_v(p) := signed(
                all_activations(
                    (p+1)*DATA_WIDTH-1 downto p*DATA_WIDTH
                )
            );
        end loop;

        for p in 0 to TOTAL_WEIGHTS-1 loop
            weights_v(p) := signed(
                all_weights(
                    (p+1)*DATA_WIDTH-1 downto p*DATA_WIDTH
                )
            );
        end loop;


        ------------------------------------------------------------
        -- 1. Output-layer delta for squared-error loss:
        --    delta = 2 * (prediction - target).
        --
        -- The output activation is linear.
        ------------------------------------------------------------
        act_start := activation_offset(
            LAYER_SIZES, LAYER_COUNT-1
        );

        neuron_count := LAYER_SIZES(LAYER_SIZES'high);

        for j in 0 to neuron_count-1 loop
            target_v := signed(
                targets(
                    (j+1)*DATA_WIDTH-1 downto j*DATA_WIDTH
                )
            );

            error_v :=
                resize(activation_v(act_start+j), ACC_WIDTH) -
                resize(target_v, ACC_WIDTH);

            delta_v(act_start+j) :=
                saturate_data(shift_left(error_v, 1));
        end loop;


        ------------------------------------------------------------
        -- 2. Hidden-layer deltas, calculated backwards.
        --
        -- delta(l) = ReLU'(activation(l)) *
        --            sum(weight(l+1) * delta(l+1))
        ------------------------------------------------------------
        for l in LAYER_COUNT-2 downto 1 loop

            act_start := activation_offset(LAYER_SIZES, l);
            next_act_start := activation_offset(LAYER_SIZES, l+1);
            weight_start := weight_offset(LAYER_SIZES, l);

            input_count := LAYER_SIZES(LAYER_SIZES'low+l);
            neuron_count := LAYER_SIZES(LAYER_SIZES'low+l+1);

            for h in 0 to input_count-1 loop
                sum_v := (others => '0');

                for j in 0 to neuron_count-1 loop

                    -- Weight from hidden neuron h to the next
                    -- layer's neuron j.
                    w_index :=
                        weight_start + j*input_count + h;

                    product_v :=
                        weights_v(w_index) *
                        delta_v(next_act_start+j);

                    sum_v := sum_v + resize(
                        shift_right(product_v, FRAC_BITS),
                        ACC_WIDTH
                    );
                end loop;

                -- Hidden layers currently use ReLU.
                if activation_v(act_start+h) <=
                   to_signed(0, DATA_WIDTH) then

                    delta_v(act_start+h) := (others => '0');

                else
                    delta_v(act_start+h) := saturate_data(sum_v);
                end if;

            end loop;
        end loop;


        ------------------------------------------------------------
        -- 3. Gradients for every dense layer.
        --
        -- Weight gradient = delta * previous activation.
        -- Bias gradient   = delta.
        --
        -- All weights are packed first, followed by all biases,
        -- matching configurable_mlp_memory's address order.
        ------------------------------------------------------------
        for l in 0 to LAYER_COUNT-2 loop

            act_start := activation_offset(LAYER_SIZES, l);
            next_act_start := activation_offset(LAYER_SIZES, l+1);
            weight_start := weight_offset(LAYER_SIZES, l);
            bias_start := bias_offset(LAYER_SIZES, l);

            input_count := LAYER_SIZES(LAYER_SIZES'low+l);
            neuron_count := LAYER_SIZES(LAYER_SIZES'low+l+1);

            for j in 0 to neuron_count-1 loop

                for i in 0 to input_count-1 loop

                    product_v :=
                        delta_v(next_act_start+j) *
                        activation_v(act_start+i);

                    w_index :=
                        weight_start + j*input_count + i;

                    gradient_v(w_index) := resize(
                        shift_right(product_v, FRAC_BITS),
                        GRAD_WIDTH
                    );
                end loop;

                b_index :=
                    TOTAL_WEIGHTS + bias_start + j;

                gradient_v(b_index) :=
                    resize(delta_v(next_act_start+j), GRAD_WIDTH);
            end loop;
        end loop;


        ------------------------------------------------------------
        -- Pack gradient and delta outputs.
        ------------------------------------------------------------
        for p in 0 to TOTAL_PARAMETERS-1 loop
            gradient_bus_v(
                (p+1)*GRAD_WIDTH-1 downto p*GRAD_WIDTH
            ) := std_logic_vector(gradient_v(p));
        end loop;

        for p in 0 to TOTAL_ACTIVATIONS-1 loop
            delta_bus_v(
                (p+1)*DATA_WIDTH-1 downto p*DATA_WIDTH
            ) := std_logic_vector(delta_v(p));
        end loop;

        gradients <= gradient_bus_v;
        all_deltas <= delta_bus_v;

    end process BACKPROPAGATION;

end architecture Behavioral;