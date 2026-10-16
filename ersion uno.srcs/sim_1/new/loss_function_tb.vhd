
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity loss_function_tb is
end loss_function_tb;

architecture Behavioral of loss_function_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant N_OUTPUTS  : positive := 2;
    constant ACC_WIDTH  : positive := 40;

    signal predictions : STD_LOGIC_VECTOR(
        N_OUTPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal targets : STD_LOGIC_VECTOR(
        N_OUTPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal loss : SIGNED(ACC_WIDTH - 1 downto 0);

begin

    uut : entity work.loss_function
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_OUTPUTS  => N_OUTPUTS,
            ACC_WIDTH  => ACC_WIDTH
        )
        port map (
            predictions => predictions,
            targets     => targets,
            loss        => loss
        );

    stimulus : process
    begin

        -- Prediction 0 = 6.0; prediction 1 = -1.5.
        -- The lowest 16-bit slice contains prediction 0.
        predictions <=
            STD_LOGIC_VECTOR(to_signed(-768, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(3072, DATA_WIDTH));

        -- Target 0 = 5.0; target 1 = -1.0.
        targets <=
            STD_LOGIC_VECTOR(to_signed(-512, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(2560, DATA_WIDTH));

        wait for 20 ns;

        -- Expected SSE = (6 - 5)^2 + (-1.5 + 1)^2
        --              = 1.0 + 0.25 = 1.25
        -- Fixed-point representation = 1.25 * 512 = 640.
        assert loss = to_signed(640, ACC_WIDTH)
            report "ERROR: Loss calculation is incorrect"
            severity error;

        report "Loss function test completed successfully."
            severity note;

        wait;
    end process;

end Behavioral;
