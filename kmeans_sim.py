

def kmeans_iter(points, centroids):
	
	new_centroids = [[0, 0], [0, 0]]
	num_points = [1, 1]

	for p in points:
		dist1 = abs(p[0] - centroids[0][0]) + abs(p[1] - centroids[0][1])
		dist2 = abs(p[0] - centroids[1][0]) + abs(p[1] - centroids[1][1])

		if dist1 < dist2:
			num_points[0] += 1
			new_centroids[0][0] += p[0]
			new_centroids[0][1] += p[1]
		else:
			num_points[1] += 1
			new_centroids[1][0] += p[0]
			new_centroids[1][1] += p[1]
			

	new_centroids[0][0] //= num_points[0]
	new_centroids[0][1] //= num_points[0]
	new_centroids[1][0] //= num_points[1]
	new_centroids[1][1] //= num_points[1]
	print(new_centroids)

	return new_centroids


center1 = (20,20)
center2 = (60, 20)
centroids = [[20,20], [60, 20]]
for num_iter in range(50):
	# center 20,20

	center1 = (center1[0]+1, center1[1] + 1)
	center2 = (center2[0], center2[1]+1)


	player_points = [(i,j) for i in range(100) for j in range(100) if (i-center1[0])**2 + (j-center1[1])**2 <= 10]
	player_points.extend([(i,j) for i in range(100) for j in range(100) if (i-center2[0])**2 + (j-center2[1])**2 <= 10])



	centroids = kmeans_iter(player_points, centroids)


	print("-------------------------------------------------------")
	print("iteration number:", num_iter)
	for x in range(100):
		for y in range(100):
			if [x,y] in centroids :
				print("O", end="")
			elif (x,y) in player_points:
				print("x", end="")
			else:
				print(".", end="")
		print("")
	print("\n\n\n")

