import os
import sys
import pygame

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720

PIXEL_SIZE = 16
NUM_X_PIXELS = SCREEN_WIDTH // PIXEL_SIZE
NUM_Y_PIXELS = SCREEN_HEIGHT // PIXEL_SIZE

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

def store_wall(wall, filename="walls.mem"):
    walls_file_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'top', 'data', filename)

    with open(walls_file_path, 'a') as f:
        hex_string = ""
        for y in range(len(wall)):
            hex_string += hex(int(''.join(str(wall[y][x]) for x in range(len(wall[y]))), 2))[2:]
        f.write(hex_string)
        

def main():
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))

    wall = []
    for y in range(NUM_Y_PIXELS):
        wall.append([1] * NUM_X_PIXELS)
        for x in range(NUM_X_PIXELS):
            if x in range(NUM_X_PIXELS//2 - 10, NUM_X_PIXELS//2 + 10) and y >= 10:
                wall[y][x] = 0
    
    mouse_down_pos = None
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mouse_down_pos = event.pos
            elif event.type == pygame.MOUSEBUTTONUP:
                mouse_down_x, mouse_down_y = mouse_down_pos
                mouse_up_x, mouse_up_y = event.pos
                print(mouse_down_y, mouse_down_x, mouse_up_y, mouse_up_x)
                for y in range(min(mouse_down_y, mouse_up_y)//PIXEL_SIZE, (max(mouse_down_y, mouse_up_y) + 2)//PIXEL_SIZE):
                    for x in range(min(mouse_down_x, mouse_up_x)//PIXEL_SIZE, (max(mouse_down_x, mouse_up_x) + 2)//PIXEL_SIZE):
                        wall[y][x] = 1 - wall[y][x]
                

        screen.fill(WHITE)
        for y in range(NUM_Y_PIXELS):
            for x in range(NUM_X_PIXELS):
                if wall[y][x] == 1:
                    pygame.draw.rect(screen, PINK, (x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE))
                pygame.draw.rect(screen, BLACK, (x * PIXEL_SIZE, y * PIXEL_SIZE, PIXEL_SIZE, PIXEL_SIZE), 1)

        pygame.display.flip()
        pygame.time.Clock().tick(10)
    

    # print_wall(wall)
    # store_wall(wall)
    
if __name__ == "__main__":
    main()
