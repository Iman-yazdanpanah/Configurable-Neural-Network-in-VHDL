
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity linear_gradients_tb is
end linear_gradients_tb;

architecture Behavioral of linear_gradients_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant N_INPUTS   : positive := 2;
    constant GRAD_WIDTH : positive := 32;

    signal inputs : STD_LOGIC_VECTOR(
        N_INPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal prediction : SIGNED(DATA_WIDTH - 1 downto 0)
        := (others => '0');

    signal target : SIGNED(DATA_WIDTH - 1 downto 0)
        := (others => '0');
    signal output_delta : SIGNED(DATA_WIDTH - 1 downto 0);
    
    signal weight_gradients : STD_LOGIC_VECTOR(
        N_INPUTS * GRAD_WIDTH - 1 downto 0
    );

    signal bias_gradient : SIGNED(GRAD_WIDTH - 1 downto 0);

begin

    uut : entity work.linear_gradients
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            GRAD_WIDTH => GRAD_WIDTH
        )
        port map (
            inputs           => inputs,
            prediction       => prediction,
            target           => target,
            weight_gradients => weight_gradients,
            output_delta => output_delta,
            bias_gradient    => bias_gradient
        );

    stimulus : process
    begin

        -- Input 0 = 1.0 -> 512.
        -- Input 1 = 2.0 -> 1024.
        inputs <=
            STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        -- Prediction = 3.0 -> 1536.
        prediction <= to_signed(1536, DATA_WIDTH);

        -- Target = 1.0 -> 512.
        target <= to_signed(512, DATA_WIDTH);

        wait for 20 ns;

        -- Error = 3 - 1 = 2.
        --
        -- dL/dw0 = 2 * 2 * 1 = 4 -> 2048.
        assert signed(weight_gradients(31 downto 0)) =
               to_signed(2048, GRAD_WIDTH)
            report "ERROR: Weight 0 gradient is incorrect"
            severity error;

        -- dL/dw1 = 2 * 2 * 2 = 8 -> 4096.
        assert signed(weight_gradients(63 downto 32)) =
               to_signed(4096, GRAD_WIDTH)
            report "ERROR: Weight 1 gradient is incorrect"
            severity error;

        -- dL/db = 2 * 2 = 4 -> 2048.
        assert bias_gradient = to_signed(2048, GRAD_WIDTH)
            report "ERROR: Bias gradient is incorrect"
            severity error;
        assert output_delta = to_signed(2048, DATA_WIDTH)
            report "ERROR: Output delta should be 4.0"
            severity error;
        
        report "Output delta test passed." severity note;
        
        report "Linear gradient test completed successfully."
            severity note;

        wait;

    end process;

end Behavioral;
