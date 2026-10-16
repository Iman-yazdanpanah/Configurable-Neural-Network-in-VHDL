
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parameter_update_tb is
end parameter_update_tb;

architecture Behavioral of parameter_update_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant GRAD_WIDTH : positive := 32;
    constant N_WEIGHTS  : positive := 2;
    constant N_BIASES   : positive := 1;

    signal weights : STD_LOGIC_VECTOR(
        N_WEIGHTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal weight_gradients : STD_LOGIC_VECTOR(
        N_WEIGHTS * GRAD_WIDTH - 1 downto 0
    ) := (others => '0');

    signal biases : STD_LOGIC_VECTOR(
        N_BIASES * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal bias_gradients : STD_LOGIC_VECTOR(
        N_BIASES * GRAD_WIDTH - 1 downto 0
    ) := (others => '0');

    signal learning_rate : SIGNED(DATA_WIDTH - 1 downto 0)
        := (others => '0');

    signal updated_weights : STD_LOGIC_VECTOR(
        N_WEIGHTS * DATA_WIDTH - 1 downto 0
    );

    signal updated_biases : STD_LOGIC_VECTOR(
        N_BIASES * DATA_WIDTH - 1 downto 0
    );

begin

    -- Instantiate the parameter updater
    uut : entity work.parameter_update
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            GRAD_WIDTH => GRAD_WIDTH,
            N_WEIGHTS  => N_WEIGHTS,
            N_BIASES   => N_BIASES
        )
        port map (
            weights          => weights,
            weight_gradients  => weight_gradients,
            biases            => biases,
            bias_gradients    => bias_gradients,
            learning_rate     => learning_rate,
            updated_weights   => updated_weights,
            updated_biases    => updated_biases
        );

    stimulus : process
    begin

        --------------------------------------------------
        -- TEST 1: Normal gradient descent
        --------------------------------------------------
        -- Q9: real value = stored integer / 512
        --
        -- Initial weights: 2.0 and 1.0
        -- Initial bias:    4.0
        -- Gradients:       1.0, 2.0, and 1.0
        -- Learning rate:   5 / 512 ~= 0.009765625
        --
        -- Expected stored results:
        -- w0 = 1024 - 5 = 1019
        -- w1 =  512 - 10 = 502
        -- b0 = 2048 - 5 = 2043

        weights <=
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH));

        weight_gradients <=
            STD_LOGIC_VECTOR(to_signed(1024, GRAD_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(512, GRAD_WIDTH));

        biases <= STD_LOGIC_VECTOR(to_signed(2048, DATA_WIDTH));

        bias_gradients <= STD_LOGIC_VECTOR(to_signed(512, GRAD_WIDTH));

        learning_rate <= to_signed(5, DATA_WIDTH);

        wait for 10 ns;

        assert signed(updated_weights(15 downto 0))
            = to_signed(1019, DATA_WIDTH)
            report "ERROR: Updated weight 0 should be 1019"
            severity failure;

        assert signed(updated_weights(31 downto 16))
            = to_signed(502, DATA_WIDTH)
            report "ERROR: Updated weight 1 should be 502"
            severity failure;

        assert signed(updated_biases(15 downto 0))
            = to_signed(2043, DATA_WIDTH)
            report "ERROR: Updated bias should be 2043"
            severity failure;

        report "TEST 1 PASSED: Normal parameter update."
            severity note;


        --------------------------------------------------
        -- TEST 2: Negative gradient
        --------------------------------------------------
        -- w0 = 1.0; gradient = -2.0
        -- w_new = 512 - (5 * -1024 / 512)
        --        = 512 + 10 = 522
        --
        -- The second weight and bias have zero gradients.

        weights <=
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        weight_gradients <=
            STD_LOGIC_VECTOR(to_signed(0, GRAD_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(-1024, GRAD_WIDTH));

        biases <= STD_LOGIC_VECTOR(to_signed(2048, DATA_WIDTH));

        bias_gradients <= STD_LOGIC_VECTOR(to_signed(0, GRAD_WIDTH));

        wait for 10 ns;

        assert signed(updated_weights(15 downto 0))
            = to_signed(522, DATA_WIDTH)
            report "ERROR: Negative gradient update should produce 522"
            severity failure;

        assert signed(updated_weights(31 downto 16))
            = to_signed(512, DATA_WIDTH)
            report "ERROR: Unchanged weight should remain 512"
            severity failure;

        assert signed(updated_biases(15 downto 0))
            = to_signed(2048, DATA_WIDTH)
            report "ERROR: Unchanged bias should remain 2048"
            severity failure;

        report "TEST 2 PASSED: Negative gradient update."
            severity note;


        --------------------------------------------------
        -- TEST 3: Positive saturation
        --------------------------------------------------
        -- Initial weight = 32760
        -- Gradient = -4096
        -- Learning rate = 5
        --
        -- New value = 32760 - (5 * -4096 / 512)
        --           = 32760 + 40
        --           = 32800
        --
        -- Maximum signed 16-bit value = 32767.
        -- Therefore, the result must saturate at 32767.

        weights <=
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(32760, DATA_WIDTH));

        weight_gradients <=
            STD_LOGIC_VECTOR(to_signed(0, GRAD_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(-4096, GRAD_WIDTH));

        biases <= STD_LOGIC_VECTOR(to_signed(2048, DATA_WIDTH));

        bias_gradients <= STD_LOGIC_VECTOR(to_signed(0, GRAD_WIDTH));

        wait for 10 ns;

        assert signed(updated_weights(15 downto 0))
            = to_signed(32767, DATA_WIDTH)
            report "ERROR: Positive saturation should produce 32767"
            severity failure;

        report "TEST 3 PASSED: Positive saturation."
            severity note;


        --------------------------------------------------
        -- All tests completed successfully
        --------------------------------------------------
        report "ALL PARAMETER UPDATE TESTS PASSED."
            severity note;

        wait;

    end process;

end Behavioral;
