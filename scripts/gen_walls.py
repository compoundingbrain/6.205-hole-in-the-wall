import os
import sys
import pygame

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720

BIT_MASK_DOWN_SAMPLE_FACTOR = 16
NUM_X_BITS = SCREEN_WIDTH // BIT_MASK_DOWN_SAMPLE_FACTOR
NUM_Y_BITS = SCREEN_HEIGHT // BIT_MASK_DOWN_SAMPLE_FACTOR
PIXEL_SIZE = 12

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
PINK = (215, 0, 193)

def print_wall(wall):
    for y in range(len(wall)):
        for x in range(len(wall[y])):
            if wall[y][x] == 1:
                print('.', end='')
            else:
                print(' ', end='')
        print('')

def store_wall(walls, filename="walls.mem"):
    walls_file_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'top', 'data', filename)

    with open(walls_file_path, 'w') as f:
        for i in range(len(walls)):
            wall = walls[i]
            hex_string = ""
            for y in range(len(wall)):
                hex_string += hex(int(''.join(str(wall[y][x]) for x in range(len(wall[y]))), 2))[2:]
            f.write(hex_string)
            if i < len(walls) - 1:
                f.write('\n')

def read_wall_file(filename="walls.mem"):
    walls_file_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'top', 'data', filename)

    walls = []

    with open(walls_file_path, 'r') as f:
        for line in f:
            wall = []
            for y in range(NUM_Y_BITS):
                wall.append([])
                for x in range(NUM_X_BITS//4):
                    hex_val = int(line[x + NUM_X_BITS//4 * y], 16)
                    wall[y].extend([
                        (hex_val>>3) & 1,
                        (hex_val>>2) & 1,
                        (hex_val>>1) & 1,
                        (hex_val>>0) & 1
                    ])
            walls.append(wall)
    
    return walls

def main():
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    font = pygame.font.Font(None, 24)

    walls = read_wall_file("walls.mem")
    wall = walls[0]
    
    mouse_down_pos = None

    dropdown_rect = pygame.Rect(1000, 100, 200, 30)
    dropdown_options = [f"Wall {i+1}" for i in range(10)]
    dropdown_selected = 0
    dropdown_open = False

    save_button_rect = pygame.Rect(1000, 50, 200, 30)

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if dropdown_rect.collidepoint(event.pos):
                    dropdown_open = not dropdown_open
                elif dropdown_open:
                    dropdown_open = False
                    wall = walls[dropdown_selected]
                elif save_button_rect.collidepoint(event.pos):
                    store_wall(walls, "walls.mem")
                elif event.pos[0] < NUM_X_BITS * PIXEL_SIZE and event.pos[1] < NUM_Y_BITS * PIXEL_SIZE:
                    mouse_down_pos = event.pos
            elif event.type == pygame.MOUSEMOTION and dropdown_open:
                for i, option in enumerate(dropdown_options):
                    option_rect = pygame.Rect(dropdown_rect.x, dropdown_rect.y + (i + 1) * 30, dropdown_rect.width, 30)
                    if option_rect.collidepoint(event.pos):
                        dropdown_selected = i
            elif event.type == pygame.MOUSEBUTTONUP and mouse_down_pos != None:
                mouse_down_x, mouse_down_y = mouse_down_pos
                mouse_up_x, mouse_up_y = event.pos
                for y in range(min(mouse_down_y, mouse_up_y)//PIXEL_SIZE, (max(mouse_down_y, mouse_up_y))//PIXEL_SIZE + 1):
                    for x in range(min(mouse_down_x, mouse_up_x)//PIXEL_SIZE, (max(mouse_down_x, mouse_up_x))//PIXEL_SIZE + 1):
                        wall[y][x] = 1 - wall[y][x]
                mouse_down_pos = None
                

        screen.fill(WHITE)
        for y in range(NUM_Y_BITS):
            for x in range(NUM_X_BITS):
                if wall[y][x] == 1:
                    pygame.draw.rect(screen, PINK, (x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE))
                pygame.draw.rect(screen, BLACK, (x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE), 1)

        # Draw the dropdown menu
        pygame.draw.rect(screen, BLACK, dropdown_rect, 1)
        text = font.render(dropdown_options[dropdown_selected], True, BLACK)
        screen.blit(text, (dropdown_rect.x + 10, dropdown_rect.y + 10))
        if dropdown_open:
            for i, option in enumerate(dropdown_options):
                option_rect = pygame.Rect(dropdown_rect.x, dropdown_rect.y + (i + 1) * 30, dropdown_rect.width, 30)
                pygame.draw.rect(screen, BLACK, option_rect, 1)
                text = font.render(option, True, BLACK)
                screen.blit(text, (option_rect.x + 10, option_rect.y + 10))

        # Draw save button
        pygame.draw.rect(screen, BLACK, save_button_rect, 1)
        text = font.render("Save", True, BLACK)
        screen.blit(text, (save_button_rect.x + 10, save_button_rect.y + 10))

        pygame.display.flip()
        pygame.time.Clock().tick(10)
    
if __name__ == "__main__":
    main()
