
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity linear_gradients is
    generic (
        DATA_WIDTH : positive := 16;
        FRAC_BITS  : natural  := 9;
        N_INPUTS   : positive := 2;
        GRAD_WIDTH : positive := 32
    );
    port (
        inputs : in STD_LOGIC_VECTOR(
            N_INPUTS * DATA_WIDTH - 1 downto 0
        );

        prediction : in SIGNED(DATA_WIDTH - 1 downto 0);
        target     : in SIGNED(DATA_WIDTH - 1 downto 0);

        -- New: output-layer error signal for backpropagation.
        output_delta : out SIGNED(DATA_WIDTH - 1 downto 0);

        weight_gradients : out STD_LOGIC_VECTOR(
            N_INPUTS * GRAD_WIDTH - 1 downto 0
        );

        bias_gradient : out SIGNED(GRAD_WIDTH - 1 downto 0)
    );
end linear_gradients;

architecture Behavioral of linear_gradients is

    constant ERR_WIDTH  : positive := DATA_WIDTH + 1;
    constant PROD_WIDTH : positive := ERR_WIDTH + DATA_WIDTH;
    constant DELTA_WIDTH : positive := DATA_WIDTH + 2;

    function saturate_gradient(
        value : SIGNED(PROD_WIDTH - 1 downto 0)
    ) return SIGNED is
        variable max_g : SIGNED(GRAD_WIDTH - 1 downto 0);
        variable min_g : SIGNED(GRAD_WIDTH - 1 downto 0);
    begin
        max_g := (others => '1');
        max_g(GRAD_WIDTH - 1) := '0';

        min_g := (others => '0');
        min_g(GRAD_WIDTH - 1) := '1';

        if value > resize(max_g, PROD_WIDTH) then
            return max_g;
        elsif value < resize(min_g, PROD_WIDTH) then
            return min_g;
        else
            return resize(value, GRAD_WIDTH);
        end if;
    end function;

    function saturate_delta(
        value : SIGNED(DELTA_WIDTH - 1 downto 0)
    ) return SIGNED is
        variable max_d : SIGNED(DATA_WIDTH - 1 downto 0);
        variable min_d : SIGNED(DATA_WIDTH - 1 downto 0);
    begin
        max_d := (others => '1');
        max_d(DATA_WIDTH - 1) := '0';

        min_d := (others => '0');
        min_d(DATA_WIDTH - 1) := '1';

        if value > resize(max_d, DELTA_WIDTH) then
            return max_d;
        elsif value < resize(min_d, DELTA_WIDTH) then
            return min_d;
        else
            return resize(value, DATA_WIDTH);
        end if;
    end function;

begin

    assert GRAD_WIDTH <= PROD_WIDTH
        report "GRAD_WIDTH must not exceed PROD_WIDTH"
        severity failure;

    process(inputs, prediction, target)
        variable error_value : SIGNED(ERR_WIDTH - 1 downto 0);
        variable x_value : SIGNED(DATA_WIDTH - 1 downto 0);

        variable full_product : SIGNED(PROD_WIDTH - 1 downto 0);
        variable scaled_product : SIGNED(PROD_WIDTH - 1 downto 0);
        variable gradient_value : SIGNED(PROD_WIDTH - 1 downto 0);

        variable delta_full : SIGNED(DELTA_WIDTH - 1 downto 0);
        variable bias_full : SIGNED(PROD_WIDTH - 1 downto 0);

        variable gradients_temp : STD_LOGIC_VECTOR(
            N_INPUTS * GRAD_WIDTH - 1 downto 0
        );

    begin
        error_value :=
            resize(prediction, ERR_WIDTH) -
            resize(target, ERR_WIDTH);

        -- SSE derivative: output_delta = 2 * (prediction - target).
        delta_full := shift_left(resize(error_value, DELTA_WIDTH), 1);

        output_delta <= saturate_delta(delta_full);

        gradients_temp := (others => '0');

        for i in 0 to N_INPUTS - 1 loop
            x_value := signed(
                inputs((i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH)
            );

            full_product := error_value * x_value;

            scaled_product := shift_right(full_product, FRAC_BITS);

            gradient_value := shift_left(scaled_product, 1);

            gradients_temp(
                (i + 1) * GRAD_WIDTH - 1 downto i * GRAD_WIDTH
            ) := std_logic_vector(saturate_gradient(gradient_value));
        end loop;

        bias_full := shift_left(resize(error_value, PROD_WIDTH), 1);

        weight_gradients <= gradients_temp;
        bias_gradient <= saturate_gradient(bias_full);
    end process;

end Behavioral;
