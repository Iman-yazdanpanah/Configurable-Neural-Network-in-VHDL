
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mlp_tb is
end mlp_tb;

architecture Behavioral of mlp_tb is

    -- Fixed-point: 16-bit signed values, 9 fractional bits.
    -- Real value = stored integer / 512.
    constant DATA_WIDTH     : positive := 16;
    constant FRAC_BITS      : natural  := 9;
    constant N_INPUTS       : positive := 2;
    constant HIDDEN_NEURONS : positive := 3;
    constant OUTPUT_NEURONS : positive := 2;
    constant ACC_WIDTH      : positive := 40;

    -- Input data: 2 x 16 = 32 bits.
    signal inputs : STD_LOGIC_VECTOR(
        N_INPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    -- Hidden weights: 3 neurons x 2 inputs x 16 = 96 bits.
    signal hidden_weights : STD_LOGIC_VECTOR(
        HIDDEN_NEURONS * N_INPUTS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    -- Hidden biases: 3 x 16 = 48 bits.
    signal hidden_biases : STD_LOGIC_VECTOR(
        HIDDEN_NEURONS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    -- Output weights: 2 neurons x 3 inputs x 16 = 96 bits.
    signal output_weights : STD_LOGIC_VECTOR(
        OUTPUT_NEURONS * HIDDEN_NEURONS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    -- Output biases: 2 x 16 = 32 bits.
    signal output_biases : STD_LOGIC_VECTOR(
        OUTPUT_NEURONS * DATA_WIDTH - 1 downto 0
    ) := (others => '0');

    -- Final predictions: 2 x 16 = 32 bits.
    signal outputs : STD_LOGIC_VECTOR(
        OUTPUT_NEURONS * DATA_WIDTH - 1 downto 0
    );

begin

    -- Instantiate the complete MLP.
    uut : entity work.mlp
        generic map (
            DATA_WIDTH     => DATA_WIDTH,
            FRAC_BITS      => FRAC_BITS,
            N_INPUTS       => N_INPUTS,
            HIDDEN_NEURONS => HIDDEN_NEURONS,
            OUTPUT_NEURONS => OUTPUT_NEURONS,
            ACC_WIDTH      => ACC_WIDTH
        )
        port map (
            inputs         => inputs,
            hidden_weights => hidden_weights,
            hidden_biases  => hidden_biases,
            output_weights => output_weights,
            output_biases  => output_biases,
            outputs        => outputs
        );

    stimulus : process
    begin

        ----------------------------------------------------
        -- 1. INPUTS
        ----------------------------------------------------
        -- x0 = 1.0 -> 512
        -- x1 = 2.0 -> 1024
        --
        -- Lowest 16 bits contain x0.
        inputs <=
            STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));


        ----------------------------------------------------
        -- 2. HIDDEN LAYER WEIGHTS
        ----------------------------------------------------
        -- Neuron 0: w0 = 1.0, w1 = 1.0
        -- Output = ReLU(1*1 + 2*1) = 3.0
        hidden_weights(31 downto 0) <=
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        -- Neuron 1: w0 = 2.0, w1 = 0.5
        -- Output = ReLU(1*2 + 2*0.5) = 3.0
        hidden_weights(63 downto 32) <=
            STD_LOGIC_VECTOR(to_signed(256, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(1024, DATA_WIDTH));

        -- Neuron 2: w0 = -1.0, w1 = 0.5
        -- Output = ReLU(1*(-1) + 2*0.5) = 0.0
        hidden_weights(95 downto 64) <=
            STD_LOGIC_VECTOR(to_signed(256, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(-512, DATA_WIDTH));

        -- All hidden biases = 0.
        hidden_biases <= (others => '0');


        ----------------------------------------------------
        -- 3. OUTPUT LAYER WEIGHTS
        ----------------------------------------------------
        -- Hidden outputs = [3.0, 3.0, 0.0].
        --
        -- Neuron 0:
        -- w0 = 1.0, w1 = 1.0, w2 = 0.0
        -- Output = 3*1 + 3*1 + 0*0 = 6.0
        output_weights(47 downto 0) <=
            STD_LOGIC_VECTOR(to_signed(0, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(512, DATA_WIDTH));

        -- Neuron 1:
        -- w0 = -1.0, w1 = 0.5, w2 = 0.0
        -- Output = 3*(-1) + 3*0.5 + 0*0 = -1.5
        output_weights(95 downto 48) <=
            STD_LOGIC_VECTOR(to_signed(0, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(256, DATA_WIDTH)) &
            STD_LOGIC_VECTOR(to_signed(-512, DATA_WIDTH));

        -- Both output biases = 0.
        output_biases <= (others => '0');


        ----------------------------------------------------
        -- 4. WAIT FOR COMBINATIONAL LOGIC
        ----------------------------------------------------
        wait for 20 ns;


        ----------------------------------------------------
        -- 5. CHECK EXPECTED RESULTS
        ----------------------------------------------------
        -- Output 0: 6.0 * 512 = 3072
        assert signed(outputs(15 downto 0)) =
               to_signed(3072, DATA_WIDTH)
            report "ERROR: Output neuron 0 is incorrect"
            severity error;

        -- Output 1: -1.5 * 512 = -768
        assert signed(outputs(31 downto 16)) =
               to_signed(-768, DATA_WIDTH)
            report "ERROR: Output neuron 1 is incorrect"
            severity error;

        report "MLP test completed successfully."
            severity note;

        wait;

    end process;

end Behavioral;
