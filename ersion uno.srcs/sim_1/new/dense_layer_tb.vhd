
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dense_layer_tb is
end dense_layer_tb;

architecture Behavioral of dense_layer_tb is

    constant DATA_WIDTH : positive := 16;
    constant FRAC_BITS  : natural  := 9;
    constant N_INPUTS   : positive := 2;
    constant N_NEURONS  : positive := 3;
    constant ACC_WIDTH  : positive := 40;

    signal inputs : STD_LOGIC_VECTOR(
        N_INPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal weights : STD_LOGIC_VECTOR(
        N_NEURONS * N_INPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal biases : STD_LOGIC_VECTOR(
        N_NEURONS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    signal outputs : STD_LOGIC_VECTOR(
        N_NEURONS * DATA_WIDTH - 1 downto 0
    );

begin

    uut : entity work.dense_layer
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            FRAC_BITS  => FRAC_BITS,
            N_INPUTS   => N_INPUTS,
            N_NEURONS  => N_NEURONS,
            ACC_WIDTH  => ACC_WIDTH
        )
        port map (
            inputs  => inputs,
            weights => weights,
            biases  => biases,
            outputs => outputs
        );

    stimulus : process
    begin

        -- Shared inputs: x0 = 1.0, x1 = 2.0.
        inputs(15 downto 0) <=
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        inputs(31 downto 16) <=
            STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH));


        -- NEURON 0:
        -- w0 = 2.0, w1 = 1.0, bias = 0
        -- ReLU(1*2 + 2*1) = 4.0
        weights(15 downto 0) <=
            STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH));

        weights(31 downto 16) <=
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));


        -- NEURON 1:
        -- w0 = -2.0, w1 = -1.0, bias = 0
        -- ReLU(1*(-2) + 2*(-1)) = 0
        weights(47 downto 32) <=
            STD_LOGIC_VECTOR(to_signed(-1024, DATA_WIDTH));

        weights(63 downto 48) <=
            STD_LOGIC_VECTOR(to_signed(-512, DATA_WIDTH));


        -- NEURON 2:
        -- w0 = 0.5, w1 = 0.5, bias = 0.5
        -- ReLU(1*0.5 + 2*0.5 + 0.5) = 2.0
        weights(79 downto 64) <=
            STD_LOGIC_VECTOR(to_signed(256, DATA_WIDTH));

        weights(95 downto 80) <=
            STD_LOGIC_VECTOR(to_signed(256, DATA_WIDTH));


        -- Pack biases: neuron 0, neuron 1, neuron 2.
        biases(15 downto 0) <=
            STD_LOGIC_VECTOR(to_signed(0, DATA_WIDTH));

        biases(31 downto 16) <=
            STD_LOGIC_VECTOR(to_signed(0, DATA_WIDTH));

        biases(47 downto 32) <=
            STD_LOGIC_VECTOR(to_signed(256, DATA_WIDTH));


        -- Allow combinational logic to settle.
        wait for 10 ns;


        -- Check neuron 0: expected 4.0 = 2048.
        assert SIGNED(outputs(15 downto 0)) =
               to_signed(2048, DATA_WIDTH)
            report "Neuron 0 FAILED: expected 4.0"
            severity error;


        -- Check neuron 1: expected 0.0 after ReLU.
        assert SIGNED(outputs(31 downto 16)) =
               to_signed(0, DATA_WIDTH)
            report "Neuron 1 FAILED: expected 0.0"
            severity error;


        -- Check neuron 2: expected 2.0 = 1024.
        assert SIGNED(outputs(47 downto 32)) =
               to_signed(1024, DATA_WIDTH)
            report "Neuron 2 FAILED: expected 2.0"
            severity error;


        report "All dense_layer tests completed successfully."
            severity note;

        wait;
    end process;

end Behavioral;
