import random

WIDTH = 100
HEIGHT = 100

class Point:
	def __init__(self, x, y):
		self.x = x
		self.y = y

	def __eq__(self, other):
		return self.x == other.x and self.y == other.y
	
	def __repr__(self):
		return f"({self.x}, {self.y})"

def kmeans_iter(points, centroids):
	k = len(centroids)
	
	new_centroids = [Point(0,0) for _ in range(k)]
	num_points = [0 for _ in range(k)]

	for p in points:
		minDist = float('inf')
		minDistCentroid = -1
		for i in range(k):
			dist = abs(p.x - centroids[i].x) + abs(p.y - centroids[i].y)
			if dist < minDist:
				minDist = dist
				minDistCentroid = i

		num_points[minDistCentroid] += 1
		new_centroids[minDistCentroid].x += p.x
		new_centroids[minDistCentroid].y += p.y			

	for i in range(k):
		if num_points[i] == 0:
			# Break out of local minima by randomly reassigning empty centroids
			# Helps converge pretty quickly ~<20 iters when one centroid gets 0 assignments
			new_centroids[i].x = random.randint(0, WIDTH)
			new_centroids[i].y = random.randint(0, HEIGHT)

		else:
			new_centroids[i].x //= num_points[i]
			new_centroids[i].y //= num_points[i]

	return new_centroids

centers = [Point(10,10), Point(40, 10)]
centroids = [Point(30, 10), Point(40,30)]
for num_iter in range(50):

	centers[0].x += 1
	centers[0].y += 1
	centers[1].y += 1

	player_points = []
	for k in range(len(centers)):
		player_points.extend([Point(i,j) for i in range(WIDTH) for j in range(HEIGHT) if (i-centers[k].x)**2 + (j-centers[k].y)**2 <= 10])

	centroids = kmeans_iter(player_points, centroids)
	print(centroids)

	print("-------------------------------------------------------")
	print("iteration number:", num_iter)
	print("-------------------------------------------------------")
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if Point(x,y) in centroids:
				print("O", end="")
			elif Point(x,y) in player_points:
				print("x", end="")
			else:
				print(".", end="")
		print("")
	print("\n\n\n")

