package org.graalvm.demo;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.FileWriter;

import org.graalvm.polyglot.*;

// A simple Java program to implement Game of Life
// Modified from https://www.geeksforgeeks.org/program-for-conways-game-of-life/
public class GameOfLife {

    private static final String JS = "js";
    private static final Context cx = Context.newBuilder(JS).allowHostAccess(HostAccess.ALL).allowPolyglotAccess(PolyglotAccess.ALL).build();
    private static final String jsSource = "\n" +
        "function alive(grid, l, m, N, M) { \n" +
        "    var aliveNeighbours = 0; \n" +
        "    for (i = -1; i <= 1; i++) { \n" +
        "        for (j = -1; j <= 1; j++) { \n" +
        "            if ((l + i >= 0 && l + i < M) && (m + j >= 0 && m + j < N)) { \n" +
        "                aliveNeighbours += grid[l + i][m + j]; \n" +
        "            } \n" +
        "        } \n" +
        "    } \n" +
        "    aliveNeighbours -= grid[l][m]; \n" +
        "    return aliveNeighbours; \n" +
        "} \n" +
        "alive";

    private static final int M = 4000;
    private static final int N = 4000;

    public static void main(String[] args) {
        new GameOfLife().run(args);
    }

    private void run(String[] args) {
        if (args.length < 3) {
            System.err.println("Too few arguments, need input file, output file and number of generations");
            System.exit(1);
        }

        String input = args[0];
        String output = args[1];
        int generations = Integer.parseInt(args[2]);

        int[][] grid = loadGrid(input);
        for (int i = 1; i <= generations; i++) {
            grid = nextGeneration(grid);
        }
        saveGrid(grid, output);
    }

    static int[][] nextGeneration(int[][] grid) {
        int[][] future = new int[M][N];
        for (int l = 0; l < M; l++) {
            for (int m = 0; m < N; m++) {
                applyRules(grid, future, l, m, getAliveNeighbours(grid, l, m));
            }
        }
        return future;
    }

    private static void applyRules(int[][] grid, int[][] future, int l, int m, int aliveNeighbours) {
        if ((grid[l][m] == 1) && (aliveNeighbours < 2)) {
            // Cell is lonely and dies
            future[l][m] = 0;
        } else if ((grid[l][m] == 1) && (aliveNeighbours > 3)) {
            // Cell dies due to over population
            future[l][m] = 0;
        } else if ((grid[l][m] == 0) && (aliveNeighbours == 3)) {
            // A new cell is born
            future[l][m] = 1;
        } else {
            // Remains the same
            future[l][m] = grid[l][m];
        }
    }

    private static int getAliveNeighbours(int[][] grid, int l, int m) {
        Value v = cx.eval(JS, jsSource);
        return v.execute(grid, l, m, N, M).asInt();
    }

    private static void saveGrid(int[][] grid, String output) {
        try (FileWriter myWriter = new FileWriter(output)) {
            for (int i = 0; i < M; i++) {
                for (int j = 0; j < N; j++) {
                    if (grid[i][j] == 0)
                        myWriter.write(".");
                    else
                        myWriter.write("*");
                }
                myWriter.write(System.lineSeparator());
            }
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private static int[][] loadGrid(String input) {
        try (BufferedReader reader = new BufferedReader(new FileReader(input))) {
            int[][] grid = new int[M][N];
            for (int i = 0; i < M; i++) {
                String line = reader.readLine();
                for (int j = 0; j < N; j++) {
                    if (line.charAt(j) == '*') {
                        grid[i][j] = 1;
                    } else {
                        grid[i][j] = 0;
                    }
                }
            }
            return grid;
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
