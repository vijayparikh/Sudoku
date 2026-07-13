require 'prawn'
require 'json' # NEW: Added standard library for JSON parsing

class Sudoku
  DIFFICULTIES = {
    easy: 35,
    medium: 43,
    hard: 50,
    expert: 55
  }.freeze

  attr_accessor :board

  def initialize(board = Array.new(9) { Array.new(9, 0) })
    @board = board
  end

  # NEW: Exports any 9x9 board array into a formatted JSON file
  def export_to_json(grid, filename = "sudoku.json")
    File.open(filename, "w") do |f|
      f.write(JSON.pretty_generate(grid))
    end
    puts "JSON successfully saved: #{filename}"
  end

  # NEW: Imports a board array from a JSON file and assigns it to the game board
  def import_from_json(filename)
    unless File.exist?(filename)
      puts "Error: File #{filename} not found."
      return false
    end

    file_content = File.read(filename)
    @board = JSON.parse(file_content)
    puts "JSON successfully imported from: #{filename}"
    @board
  end

  def solve(grid = @board)
    empty_cell = find_empty(grid)
    return grid unless empty_cell

    row, col = empty_cell

    (1..9).each do |num|
      if valid?(grid, num, row, col)
        grid[row][col] = num
        return grid if solve(grid)
        grid[row][col] = 0
      end
    end

    false
  end

  def generate_full_board
    full_board = Array.new(9) { Array.new(9, 0) }
    fill_board(full_board)
    full_board
  end

  def generate_puzzle(difficulty = DIFFICULTIES[:medium])
    #num_holes = DIFFICULTIES[difficulty.to_sym] || DIFFICULTIES[:medium]
    num_holes = difficulty || DIFFICULTIES[:medium]
    solved = generate_full_board
    puzzle = solved.map(&:dup)

    holes = 0
    attempts = 0
    max_attempts = num_holes * 10

    while holes < num_holes && attempts < max_attempts
      attempts += 1
      row = rand(9)
      col = rand(9)

      next if puzzle[row][col] == 0

      backup = puzzle[row][col]
      puzzle[row][col] = 0

      copy = puzzle.map(&:dup)
      if count_solutions(copy) != 1
        puzzle[row][col] = backup
      else
        holes += 1
      end
    end

    @board = puzzle
    puzzle
  end

  def export_to_pdf(grid, filename = "sudoku.pdf", title = "Sudoku Puzzle")
    Prawn::Document.generate(filename) do |pdf|
      pdf.text title, size: 28, style: :bold, align: :center
      pdf.move_down 40

      cell_size = 40
      grid_size = cell_size * 9
      start_x = (pdf.bounds.width - grid_size) / 2
      start_y = pdf.cursor

      (0..8).each do |row|
        (0..8).each do |col|
          x = start_x + (col * cell_size)
          y = start_y - (row * cell_size)

          pdf.stroke_color "CCCCCC"
          pdf.line_width 1
          pdf.stroke_rectangle [x, y], cell_size, cell_size

          val = grid[row][col]
          next if val == 0

          pdf.text_box val.to_s,
                       at: [x, y - 8],
                       width: cell_size,
                       height: cell_size,
                       align: :center,
                       size: 18,
                       style: :bold
        end
      end

      pdf.stroke_color "000000"
      pdf.line_width 3
      pdf.stroke_rectangle [start_x, start_y], grid_size, grid_size

      (1..2).each do |i|
        v_x = start_x + (i * cell_size * 3)
        pdf.stroke_line [v_x, start_y], [v_x, start_y - grid_size]

        h_y = start_y - (i * cell_size * 3)
        pdf.stroke_line [start_x, h_y], [start_x + grid_size, h_y]
      end
    end
    puts "PDF successfully created: #{filename}"
  end

  def print_board(grid)
    grid.each_with_index do |row, r_idx|
      puts "-------------------------" if r_idx % 3 == 0 && r_idx != 0
      row.each_with_index do |cell, c_idx|
        print "| " if c_idx % 3 == 0 && c_idx != 0
        print cell == 0 ? ". " : "#{cell} "
      end
      puts "|"
    end
    puts "-------------------------"
  end

  private

  def fill_board(grid)
    empty_cell = find_empty(grid)
    return true unless empty_cell

    row, col = empty_cell
    numbers = (1..9).to_a.shuffle

    numbers.each do |num|
      if valid?(grid, num, row, col)
        grid[row][col] = num
        return true if fill_board(grid)
        grid[row][col] = 0
      end
    end

    false
  end

  def find_empty(grid)
    (0..8).each do |row|
      (0..8).each do |col|
        return [row, col] if grid[row][col] == 0
      end
    end
    nil
  end

  def valid?(grid, num, row, col)
    return false if grid[row].include?(num)
    return false if grid.transpose[col].include?(num)

    box_row = row / 3 * 3
    box_col = col / 3 * 3
    (box_row...box_row + 3).each do |r|
      (box_col...box_col + 3).each do |c|
        return false if grid[r][c] == num
      end
    end

    true
  end

  def count_solutions(grid, count = 0)
    empty_cell = find_empty(grid)
    return count + 1 unless empty_cell

    row, col = empty_cell

    (1..9).each do |num|
      if valid?(grid, num, row, col)
        grid[row][col] = num
        count = count_solutions(grid, count)
        return count if count > 1
        grid[row][col] = 0
      end
    end

    count
  end
end

# --- Usage Example ---

sudoku = Sudoku.new
chosen_difficulty =  Sudoku::DIFFICULTIES[:easy]

# 1. Generate and save a puzzle state
puts "=== 1. Generating Puzzle ==="
generated_puzzle = sudoku.generate_puzzle(chosen_difficulty)
sudoku.export_to_json(generated_puzzle, "my_puzzle.json")
sudoku.export_to_pdf(generated_puzzle, "sudoku_puzzle.pdf", "Sudoku (#{chosen_difficulty.to_s.capitalize})")

# 2. Reset our application and read it back from the file system
puts "\n=== 2. Importing Saved Puzzle ==="
another_sudoku_instance = Sudoku.new
imported_puzzle = another_sudoku_instance.import_from_json("my_puzzle.json")
another_sudoku_instance.print_board(imported_puzzle)

# 3. Solve the imported board configuration
puts "\n=== 3. Solving Imported Puzzle ==="
solved_board = another_sudoku_instance.solve(imported_puzzle)
another_sudoku_instance.print_board(solved_board)
another_sudoku_instance.export_to_pdf(solved_board, "sudoku_solution.pdf", "Sudoku Solution")
