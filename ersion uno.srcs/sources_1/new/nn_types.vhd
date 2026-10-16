library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package nn_types is

    -- Supported activation functions
    type activation_t is (
        LINEAR,
        RELU
    );

    -- Number of neurons in each network layer.
    -- Example: (2, 4, 4, 2)
    type positive_array_t is array (natural range <>) of positive;

    -- Count all weights between consecutive layers.
    function network_weight_count(
        sizes : positive_array_t
    ) return natural;

    -- Count biases in all non-input layers.
    function network_bias_count(
        sizes : positive_array_t
    ) return natural;

    -- Count all parameters: weights followed by biases.
    function network_parameter_count(
        sizes : positive_array_t
    ) return positive;

    -- Count neurons across all layers, for activation storage.
    function network_activation_count(
        sizes : positive_array_t
    ) return positive;

end package nn_types;


package body nn_types is

    function network_weight_count(
        sizes : positive_array_t
    ) return natural is
        variable total : natural := 0;
    begin
        if sizes'length >= 2 then
            for k in sizes'low to sizes'high - 1 loop
                total := total + sizes(k) * sizes(k + 1);
            end loop;
        end if;

        return total;
    end function;


    function network_bias_count(
        sizes : positive_array_t
    ) return natural is
        variable total : natural := 0;
    begin
        if sizes'length >= 2 then
            for k in sizes'low + 1 to sizes'high loop
                total := total + sizes(k);
            end loop;
        end if;

        return total;
    end function;


    function network_parameter_count(
        sizes : positive_array_t
    ) return positive is
        variable total : natural;
    begin
        if sizes'length < 2 then
            return 1;
        end if;

        total :=
            network_weight_count(sizes) +
            network_bias_count(sizes);

        return total;
    end function;


    function network_activation_count(
        sizes : positive_array_t
    ) return positive is
        variable total : natural := 0;
    begin
        for k in sizes'low to sizes'high loop
            total := total + sizes(k);
        end loop;

        return total;
    end function;

end package body nn_types;