import numpy as np
from pymagnitude import Magnitude
from sys import argv
from numba import njit
from scipy.special import comb
from itertools import combinations

vectors = {}
sigma_cache = {}

def main():
    '''Usage: python WEAT.py [path to magnitude files] [filenames of word lists X, Y, A, B]
    Print out the effect size d, and the p-value'''
    magnitude = Magnitude(argv[1], dtype=np.float64)
    filenames = argv[2:]
    sets = []
    for filename in filenames:
        with open(filename) as input_file:
            words = [line.strip() for line in input_file.readlines()]
        sets.append(words)
    assert len(sets[0]) == len(sets[1])
    assert len(sets[2]) == len(sets[3])
    for s in sets:
        for w in s:
            vectors[w] = magnitude.query(w)

    print('%.16f %.16f' % (compute_d(*sets), compute_p(*sets)))

def partitions(X, Y):
    '''Return half-sized partitions of the union of X and Y'''
    XY = X + Y
    n = len(XY)
    k = n // 2
    Xi = [0] * k
    Yi = [0] * k
    for x_indices in combinations(range(n), k):
        x_indices = set(x_indices)
        px = py = 0
        for p in range(n):
            if p in x_indices:
                Xi[px] = XY[p]
                px += 1
            else:
                Yi[py] = XY[p]
                py += 1
        yield (Xi, Yi)

def compute_p(X, Y, A, B):
    '''Compute p-value'''
    count = 0
    observed = s(X, Y, A, B)
    for Xi,Yi in partitions(X, Y):
        if (s(Xi, Yi, A, B) > observed):
            count += 1
    n = (len(X) + len(Y))
    return count / comb(n, n//2)

def compute_d(X, Y, A, B):
    '''Compute effect size'''
    sigma_x = np.array([sigma(x, A, B) for x in X])
    sigma_y = np.array([sigma(y, A, B) for y in Y])
    mean_diff = np.mean(sigma_x) - np.mean(sigma_y)
    pooled_sd = np.sqrt((np.var(sigma_x, ddof=1) + np.var(sigma_y, ddof=1)) / 2)
    return mean_diff / pooled_sd

def s(X, Y, A, B):
    sum_x = sum(map(lambda x: sigma(x, A, B), X))
    sum_y = sum(map(lambda y: sigma(y, A, B), Y))
    return sum_x - sum_y

def sigma(w, A, B):
    if w not in sigma_cache:
        sum_a = sum(map(lambda a: cos(w, a), A))
        sum_b = sum(map(lambda b: cos(w, b), B))
        sigma_cache[w] = sum_a / len(A) - sum_b / len(B)
    return sigma_cache[w]

def cos(a, b):
    return ncos(vectors[a], vectors[b])

@njit
def ncos(a, b):
    '''Return the dot product of `a` and `b`, which is equal to the cosine of the angle between `a` and `b`.
    This is allowed, because vector radii are normalized'''
    return np.dot(a, b)

main()
