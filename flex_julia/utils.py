import os, shutil, subprocess, importlib, re, pickle, math, array, fcntl, time, random, math, time
import numpy as np
import matplotlib.pyplot as plt
import urllib.request
from glob import iglob
from glob import glob
from pathlib import Path

def objtoarr(path, symbol="v"):
    dicts={"v": "Vertices", 
           "s": "Velocities",
           "V": "Vertices", 
           "S": "Velocities"}
    flag=False
    out_list = []
    with open(path) as f:
        lines = f.readlines()
    for i in range(len(lines)):
        if not lines[i] or len(lines[i]) <= 1:
            continue
        line_splited = lines[i].split()   
        if (line_splited[1] == dicts[symbol] and lines[i+2][0] == symbol) or (line_splited[0] == "o" and lines[i+2][0] == symbol):
            flag = True
        elif flag and line_splited[0] == "#":
            return out_list
        elif flag:
            if len(line_splited) < 4:
                continue
            else:
                cur_arr=[float(line_splited[1]), float(line_splited[2]), float(line_splited[3])]
                out_list.append(cur_arr)
    return out_list


def load_pos_vel(filename=None):
    cloth_pos = []
    cloth_vel = []
    cloth_faces = []
    obj_pos = []
    obj_vel = []
    with open(filename) as f:
        lines = f.readlines()
        lines = [line.rstrip() for line in lines]
    for line in lines:
        line = line.split(" ")
        if len(line) == 4:
            if line[0] == "v":
                cloth_pos.append([float(i) for i in line[1:4]])
            elif line[0] == "f":
                cloth_faces.append([float(i) for i in line[1:4]])
            elif line[0] == "s":
                cloth_vel.append([float(i) for i in line[1:4]])
            elif line[0] == "V":
                obj_pos.append([float(i) for i in line[1:4]])
            elif line[0] == "S":
                obj_vel.append([float(i) for i in line[1:4]])
    return str(cloth_pos), str(cloth_vel), str(obj_pos), str(obj_vel)


def rm_capital_for_render(infile, outfile, rm_symbols=None):
    if rm_symbols is None:
        rm_symbols = {"# Vel", "s", "S", "# Spr", "i", "I", "l", "L", "t", "T", "# Nor", "n", "N", "# Tim"}
    with open(infile, "r") as f:
        lines = f.readlines()
    with open(outfile, "w") as f:
        for line in lines:
            if line[0] != "#" and line[0] not in rm_symbols:
                f.write(line.lower())
            elif line[0] == "#" and line[0:5] not in rm_symbols:
                f.write(line.lower())
    return

def numericalSort(value):
    numbers = re.compile(r'(\d+)')
    parts = numbers.split(value)
    parts[1::2] = map(int, parts[1::2])
    return parts

def getFilesList(path, fileType='', subDirs=False, lookupStr = '', onlyDir=False, forceSort=False):
    filesList = sorted(subDirs and iglob(path + (fileType == '' and '/**' or '/**/*.' + fileType), recursive=True) or iglob(path + (fileType == '' and '/*' or '/*.' + fileType)), key=subDirs and numericalSort or None)
    if isinstance(lookupStr, list):
        filesList = [filePath for filePath in filesList if all([luStr in filePath for luStr in lookupStr])]
    elif lookupStr != '':
        filesList = [filePath for filePath in filesList if lookupStr in filePath]
    if onlyDir:
        dirs = []
        for f in filesList:
            if os.path.isdir(f):
                dirs.append(f)
        filesList = dirs
    if forceSort:
        filesList.sort(key=lambda f: int(re.sub('\D+', '', f)))
    return filesList

def ls(dir_):
    return iglob(os.path.join(dir_, "*"))

def mkdirs(paths):
    try:
        if isinstance(paths, list) and not isinstance(paths, str):
            for path in paths:
                mkdir(path)
        else:
            mkdir(paths)
    except:
        time.sleep(random.random()/5)
        if isinstance(paths, list) and not isinstance(paths, str):
            for path in paths:
                mkdir(path)
        else:
            mkdir(paths)

def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def fileExist(path):
    if path != '/':
        if os.path.isdir(path):
            return True
        else:
            temp = Path(path)
            return temp.is_file()
    else:
        return False

def mv(src, dest):
    shutil.move(src, dest)

def cp(src, dest):
    shutil.copyfile(src, dest)

def rm(path):
    if fileExist(path):
        if os.path.isdir(path):
            shutil.rmtree(path)
        else:
            os.remove(path)

def loadPickle(filePath):
    data = None
    with open(filePath, 'rb') as f:
        data = pickle.load(f)
    return data

def savePickle(filePath, data, protocol=pickle.HIGHEST_PROTOCOL):
    with open(filePath, 'wb') as f:
        pickle.dump(data, f, protocol=protocol)

def loadTxt(filePath, splitLines=False, splitText='', lookupStr=None):
    if fileExist(filePath):
        with open(filePath, 'r') as f:
            if not splitLines:
                allLines = f.read()
            else:
                allLines = []
                for line in f.read().splitlines():
                    if line != '':
                        allLines.append(line)
        if lookupStr is not None:
            lookupRes = False
            if splitLines:
                for line in allLines:
                    if splitText != '':
                        line = line.split(splitText)
                    lookupRes = lookupStr in line
                    if lookupRes:
                        break
            else:
                lookupRes = lookupStr in allLines
            return lookupRes == True and 1 or 0

        else:
            return allLines
    else:
        return -1

def numLinesInFile(filePath):
    return sum(1 for line in open(filePath))

def appendSaveTxt(filePath, text, beginWith='', endWith='\n', noDuplicate=False, writeLockFlagPath=None):

    if writeLockFlagPath is not None:
        writeFlag = False
        while not writeFlag:
            if fileExist(writeLockFlagPath + '/noWriteFlag.txt'):
                writeFlag = False
                time.sleep(0.1)
            else:
                with open(writeLockFlagPath + '/noWriteFlag.txt', 'w') as f:
                    f.write('')
                writeFlag = True

    if noDuplicate:
        readRes = loadTxt(filePath, lookupStr=text)
        if readRes == 1:
            return 1

    if fileExist(filePath) and beginWith=='':
        beginWith='\n'

    with open(filePath, 'a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(beginWith + text + endWith)
        fcntl.flock(f, fcntl.LOCK_UN)

    if writeLockFlagPath is not None:
        rm(writeLockFlagPath + '/noWriteFlag.txt')

    return 1

def getPrestoredRenderPaths(renderResultsPath, category, trainOrTest, renderType, resolution, simultaneousRot):
    mainCategoryPath = renderResultsPath + '/' + trainOrTest + '/' + category
    renderPath = mainCategoryPath + '/' + str(resolution) + (renderType == 'depth' and '-DepthRenderPaths' or renderType == 'normal' and '-NormalRenderPaths' or (simultaneousRot == 0 and '-RGBRenderPaths' or '-RGBSimultaneousRotRenderPaths')) + '.txt'
    paths = sorted(loadTxt(renderPath, splitLines=True), key=numericalSort)
    return paths

def saveDataRow(filePath, textList, resolution, simultaneousRot):
    writeFlag = False
    while not writeFlag:
        if fileExist(filePath + '/noWriteFlag.txt'):
            writeFlag = False
            time.sleep(0.15)
        else:
            with open(filePath + '/noWriteFlag.txt', 'w') as f:
                f.write('')
            writeFlag = True


    fileNames = ['_{0:s}AllRgbNpyPaths.txt'.format(str(resolution)), '_{0:s}AllDepthNpyPaths.txt'.format(str(resolution)), '_{0:s}AllNormalNpyPaths.txt'.format(str(resolution))]
    for i, fn in enumerate(fileNames):
        if simultaneousRot == 1 and i == 0:
            data = textList[0][0]
        else:
             data = textList[i]
        with open(filePath + '/' + fn, 'a') as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            f.write('\n'.join(data) + '\n')
            fcntl.flock(f, fcntl.LOCK_UN)

    if simultaneousRot == 1:
        fileNames = ['_{0:s}AllRgbNpySimultaneousRotPaths.txt'.format(str(resolution)), '_{0:s}AllRgbNpySimultaneousRotRotationVecsPaths.txt'.format(str(resolution))]
        for i, fn in enumerate(fileNames):
            data = textList[0][i+1]
            with open(filePath + '/' + fn, 'a') as f:
                fcntl.flock(f, fcntl.LOCK_EX)
                f.write('\n'.join(data) + '\n')
                fcntl.flock(f, fcntl.LOCK_UN)
    rm(filePath + '/noWriteFlag.txt')

def saveObjPath(txtDir, objPath):
    mkdir(txtDir)
    with open(txtDir + '/objPath.txt', 'w') as txtFile:
        objPath += '\n'
        txtFile.write(objPath)


def saveRotation(txtDir, rot, simultaneousRot):
    addToList = True
    newFile = False
    if fileExist(txtDir + '/rotations.txt'):
        rots = np.loadtxt(txtDir + '/rotations.txt')
        if rots.ndim == 1:
            rots = rots.reshape(1, rots.shape[0])
        if any(np.isclose(rots, rot.reshape(1, 3)).all(1)):
            addToList = False
    else:
        newFile = True
    with open(txtDir + '/rotations.txt', 'a') as txtFile:
        if addToList:
            rot = np.array_str(rot)[1:-1].strip()
            rot = newFile and not simultaneousRot and ('0.0 0.0 0.0\n' + rot + '\n') or rot + '\n'
            txtFile.write(rot)

def readNpyPaths(path, resolution, sortedDataset, simultaneousRot):
    npyFiles = [path + '/' + '_{0:s}AllRgbNpyPaths.txt'.format(str(resolution)), path + '/' +'_{0:s}AllDepthNpyPaths.txt'.format(str(resolution)), path + '/' +'_{0:s}AllNormalNpyPaths.txt'.format(str(resolution)), path + '/' +'_{0:s}AllRgbNpySimultaneousRotPaths.txt'.format(str(resolution)), path + '/' +'_{0:s}AllRgbNpySimultaneousRotRotationVecsPaths.txt'.format(str(resolution))]
    npyPaths = []
    objNpy = []
    loopCount = simultaneousRot==1 and len(npyFiles) or len(npyFiles)-1
    for i in range(loopCount):
        npyPaths.append(sorted(list(set(loadTxt(npyFiles[i], splitLines=True))), key=numericalSort))
        objNpy.append([',,'.join(path.split(',,')[1:]) for path in npyPaths[i]])

    validNpys = set(objNpy[0])
    for i in range(1, loopCount):
        validNpys = validNpys & set(objNpy[i])
    validNpys = list(validNpys)

    for i in range(len(npyPaths)):
        npyPaths[i] = [npyPath for npyPath in npyPaths[i] if ',,'.join(npyPath.split(',,')[1:]) in validNpys]

    if not sortedDataset:
        permutationIndices = list(range(len(validNpys)))
        random.shuffle(permutationIndices)
        for i in range(loopCount):
            tempList = []
            for idx in permutationIndices:
                tempList.append(npyPaths[i][idx])
            npyPaths[i] = tempList
        
    return npyPaths

def chunkNpyPaths(npyPaths, resolution, numVPs, numRotation, numBitsPerPixel, maxMemory):
    samplesPerChunk = maxNumRenderingsSetsInMem(resolution=resolution, numVPs=numVPs, numRotation=numRotation, maxMemInMB=maxMemory, numBitsPerPixel=numBitsPerPixel, numSets=len(npyPaths))
    chunkedSamples = []
    sampleCounter = 0

    for i in range(len(npyPaths)):
        chunkedSamples.append([])
        for j in range(len(npyPaths[i])):
            if j % samplesPerChunk == 0:
                chunkedSamples[i].append([])
            chunkedSamples[i][len(chunkedSamples[i])-1].append(npyPaths[i][j])
    return chunkedSamples

def saveCombinedNpys(combinedNpysPath, chunkedSamples, resolution, numVPs, numRotation, numBitsPerPixel):

    dtype = numBitsPerPixel == 16 and np.float16 or np.float32
    catNames = []
    catIDs = []
    for i in range(len(chunkedSamples)-1):
        renderType = i == 0 and 'npyRgb' or i == 1 and 'npyDepth' or i == 2 and 'npyNormal' or i == 3 and 'npySimRot'
        mkdir(combinedNpysPath + '/' + renderType)
        mkdir(combinedNpysPath + '/catName')
        mkdir(combinedNpysPath + '/catID')
        mkdir(combinedNpysPath + '/gtIdx')
        mkdir(combinedNpysPath + '/npyRotVec')
        for j in range(len(chunkedSamples[i])):
            numNps = len(chunkedSamples[i][j])
            if numNps > 1:
                if i == 0 or i == 2:
                    arraySize=(numNps, numVPs, 3, resolution, resolution)
                elif i == 1:
                    arraySize=(numNps, numVPs, 1, resolution, resolution)
                else:
                    arraySize=(numNps, numRotation, 3, resolution, resolution)
                    arraySizeRotVecs=(numNps, numRotation, 3)
                    tempNpArrRotVecs = np.zeros(arraySizeRotVecs, dtype=np.float32)
                tempNpArr = np.zeros(arraySize, dtype=np.float32)

                currentNpySum = 0
                npyGtIdx = np.empty(0, dtype=np.float32)
                npyCatID = np.empty(0, dtype=np.float32)
                npyRotationVecs = np.empty(0, dtype=np.float32)
                for k, dataRow in enumerate(chunkedSamples[i][j]):
                    dataRow = dataRow.split(',,')
                    if i == 3:
                        dataRowRotVecs = chunkedSamples[i+1][j][k]
                        dataRowRotVecs = dataRowRotVecs.split(',,')
                        npyRotVecsPath = dataRowRotVecs[0]
                    npyPath = dataRow[0]
                    labels = dataRow[1:-1]

                    catName = labels[0]
                    if i == 0:
                        npyCatID = np.append(npyCatID, labels[1])
                        npyGtIdx = np.append(npyGtIdx, labels[2])

                    if (labels[1] + ',,' + labels[0]) not in catNames and loadTxt(combinedNpysPath + '/allCatNames.txt', splitLines=True, lookupStr=labels[0]) != 1:
                        catNames.append(labels[1] + ',,' + labels[0])
                    if labels[1] not in catIDs and loadTxt(combinedNpysPath + '/allCatIDs.txt', splitLines=True, lookupStr=labels[1]) != 1:
                        catIDs.append(labels[1])

                    try:
                        currentNpy = np.load(npyPath)
                        if i == 3:
                            currentNpyRotVecs = np.load(npyRotVecsPath)
                    except:
                        time.sleep(200)
                        currentNpy = np.load(npyPath)
                        if i == 3:
                            currentNpyRotVecs = np.load(npyRotVecsPath)

                    currentNpy = currentNpy.astype(np.float32)
                    tempNpArr[k] = currentNpy
                    if i == 3:
                        tempNpArrRotVecs[k] = currentNpyRotVecs
                        del currentNpyRotVecs
                    currentNpySum += currentNpy.sum()
                    del currentNpy
                    if i == 0:
                        appendSaveTxt(combinedNpysPath + '/catName' + '/' + str(j) + '.txt', catName)
                if i == 0:
                    np.save(combinedNpysPath + '/catID' + '/' + str(j) + '.npy', npyCatID.reshape(npyCatID.size, 1).astype(np.float32))
                    np.save(combinedNpysPath + '/gtIdx' + '/' + str(j) + '.npy', npyGtIdx.reshape(npyGtIdx.size, 1).astype(np.float32))
                np.save(combinedNpysPath + '/' + renderType + '/' + str(j) + '.npy', tempNpArr)
                if i == 3:
                    np.save(combinedNpysPath + '/npyRotVec' + '/' + str(j) + '.npy', tempNpArrRotVecs)
            if (j+1) % 20 == 0:
                print ('==> Done creating ' + str(j+1) + '/' + str(len(chunkedSamples[i])) + ' files for ' + renderType)
            if j == len(chunkedSamples[i])-1:
                print ('==> Done creating all npy files for ' + renderType)
        print ('')

        if i == 0:
            catNames = sorted(catNames, key=numericalSort)
            catNames = [name.split(',,')[1] for name in catNames]
            appendSaveTxt(combinedNpysPath + '/allCatNames.txt', '\n'.join(catNames), noDuplicate=True)
            appendSaveTxt(combinedNpysPath + '/allCatIDs.txt', '\n'.join(sorted(catIDs, key=numericalSort)), noDuplicate=True)


def convertTxtToNpy(filePath, fileName):
    txtNumpy = np.loadtxt(filePath + '/' + fileName + '.txt')
    np.save(filePath + '/' + fileName + '.npy', txtNumpy)

def equidistantPointsOnSphere(radius, numPoints, randomize=True):
    rnd = 1.
    if randomize:
        rnd = np.random.random() * numPoints

    points = []
    offset = 2./numPoints
    increment = math.pi * (3. - math.sqrt(5.))

    poseList = np.random.choice(numPoints, numPoints, replace=False).astype(np.int32)
    for i in poseList:
        y = ((i * offset) - 1) + (offset / 2)
        r = math.sqrt(1 - pow(y,2))

        phi = ((i + rnd) % numPoints) * increment

        x = math.cos(phi) * r
        z = math.sin(phi) * r

        points.append([x*radius,y*radius,z*radius])
    return np.asarray(points)


def getMinMaxDepth(path, minn, maxx, numVPs, resolution, renderAccuracy, renderType='depth'):
    for i in range(numVPs):
        fp = path[0:len(path)-6] + str(i) + '1.exr'
        if not fileExist(fp):
            fp = path[0:len(path)-7] + str(i) + '1.exr'
        npArr = exrToNumpy(fp, renderType=renderType, resolution=resolution, renderAccuracy=renderAccuracy, rawArray=True)
        if maxx < npArr[npArr<npArr.max()].max():
            maxx = npArr[npArr<npArr.max()].max()
        if minn > npArr[npArr<npArr.max()].min():
            minn = npArr[npArr<npArr.max()].min()
    return (minn, maxx)

def maxNumRenderingsSetsInMem(resolution, numVPs, numRotation, maxMemInMB, numBitsPerPixel, numSets=4):
    totalMBs = 0
    numSetsInChunk = 0
    while True:
        for i in range(numSets):
            if i == 0 or i == 2:
                totalMBs += (numVPs*resolution**2*3*numBitsPerPixel/8/1024/1024)
            elif i == 1:
                totalMBs += (numVPs*resolution**2*numBitsPerPixel/8/1024/1024)
            else:
                totalMBs += (numRotation*resolution**2*3*numBitsPerPixel/8/1024/1024)
        if totalMBs + 20 < maxMemInMB:
            numSetsInChunk+=1
        else:
            break
    return numSetsInChunk

def eulerToQuat(rotVec):
    roll, pitch, yaw = np.radians(rotVec)

    qx = np.sin(roll/2) * np.cos(pitch/2) * np.cos(yaw/2) - np.cos(roll/2) * np.sin(pitch/2) * np.sin(yaw/2)
    qy = np.cos(roll/2) * np.sin(pitch/2) * np.cos(yaw/2) + np.sin(roll/2) * np.cos(pitch/2) * np.sin(yaw/2)
    qz = np.cos(roll/2) * np.cos(pitch/2) * np.sin(yaw/2) - np.sin(roll/2) * np.sin(pitch/2) * np.cos(yaw/2)
    qw = np.cos(roll/2) * np.cos(pitch/2) * np.cos(yaw/2) + np.sin(roll/2) * np.sin(pitch/2) * np.sin(yaw/2)

    return [qx, qy, qz, qw]

def quatToEuler(qxqyqzqw):
    qx, qy, qz, qw = qxqyqzqw[0], qxqyqzqw[1], qxqyqzqw[2], qxqyqzqw[3]
    yaw = np.arctan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy ** 2 + qz ** 2))
    pitch = np.arcsin(2 * (qw * qy - qz * qx))
    roll = np.arctan2(2 * (qw * qx + qy * qz), 1 - 2 * (qx ** 2 + qy ** 2))

    return [roll, pitch, yaw]

def normalizeEuler(rotVec, rotLimitDegree, unnormalize=False):
    rx, ry, rz = rotVec
    if unnormalize:
        return (np.array([rx, ry, rz]) * 2 - 1) * rotLimitDegree
    else:
        return (np.array([rx, ry, rz]) / rotLimitDegree + 1) / 2

def addDelta(npArray, minValueAllowed=None, maxValueAllowed=None):
    if not isinstance(npArray, np.ndarray):
        array = np.array(npArray, dtype=np.float32)
    else:
        array = npArray
    array += np.random.uniform(-0.01, 0.01, size=array.shape)
    if minValueAllowed is not None:
        array[array<minValueAllowed] = minValueAllowed
    if maxValueAllowed is not None:
        array[array>maxValueAllowed] = maxValueAllowed
    return array

def computeNumShapes(numStimuli, testCategory, numDistractorShapesPerTrial):
    while True:
        if numStimuli % len(testCategory) == 0 and (numStimuli/2) % len(testCategory) == 0:
            break
        else:
            numStimuli += 1
    numStimuli = numStimuli

    numShapeFromGtCat = (numStimuli/2)/len(testCategory)*numDistractorShapesPerTrial + numStimuli/len(testCategory)
    numShapeFromDistractorCats = (numStimuli * (numDistractorShapesPerTrial+1) - numShapeFromGtCat*len(testCategory))/len(testCategory)
    
    return (int(numShapeFromGtCat), int(numShapeFromDistractorCats))


def getSolidName(numCameras):
    if numCameras == 4:
        print ('==> Error: You need to implement tetrahedron')
        sys.exit()
    elif numCameras == 6:
        print ('==> Error: You need to implement octahedron')
        sys.exit()
    elif numCameras == 8:
        return 'Cube'
    elif numCameras == 12:
        return 'Icosahedron'
    elif numCameras == 20:
        return 'Dodecahedron'
    else:
        return 'Sphere'


def concatList(inputList, lastItemIndex=-1):
    concatList = []
    if isinstance(inputList[0], list):
        for i in range(lastItemIndex == -1 and len(inputList) or lastItemIndex):
            concatList += inputList[i]
    else:
        lastItemIndex = lastItemIndex == -1 and len(inputList)+1 or lastItemIndex
        return inputList[:lastItemIndex]
    return concatList

def extractGtGtOrGtDif(stimuliStats, gt, numStimuli=120, needIndices=False):
    stimuliStatsSubset = []
    indices = []
    gtGt = True
    for i in range(numStimuli):
        if i > 0 and i % 6 == 0:
            gtGt = not gtGt
        if (gtGt and gt) or (not gtGt and not gt):
            stimuliStatsSubset.append(stimuliStats[i])
            indices.append(i)

    if needIndices:
        return stimuliStatsSubset, indices
    else:
        return stimuliStatsSubset

def makeDistinctColors(numDistinctColors=10):
    cm = plt.get_cmap('gist_rainbow')
    colors = []
    for i in range(numDistinctColors):
        colors.append(cm(i/numDistinctColors))
    return colors

def makeColorList(numStimuli=120, paintCategories=False, numCategories=10, switchGtGtAndGtDif=6):
    if paintCategories:
        if numStimuli % numCategories != 0:
            raise Exception("==> Error: Please make sure numStimuli is divisible by numCategories")
        else:
            switchCategoryEvery = numStimuli // numCategories
            distinctColors = makeDistinctColors(numDistinctColors=numCategories)

    colors = []
    gtGt=True
    catID = 0
    for i in range(numStimuli):
        if i > 0 and i % switchGtGtAndGtDif == 0:
            gtGt = not gtGt

        if not paintCategories:
            colors.append(gtGt and [0.15, 0.15, 0.95, 0.9] or [0.95, 0.15, 0.15, 0.9])
        else:
            if i > 0 and i % switchCategoryEvery == 0:
                catID += 1
            colors.append(list(distinctColors[catID]))
    if paintCategories:
        return colors, distinctColors
    else:
        return colors






def scp(src, dest, uname, serv, passwd):
    import paramiko as pmk
    from scp import SCPClient

    ssh = pmk.SSHClient()
    ssh.set_missing_host_key_policy(pmk.AutoAddPolicy())
    ssh.load_system_host_keys()
    ssh.connect(host, username=uname, password=passwd)

    with SCPClient(ssh.get_transport()) as scp:
        scp.get(src, local_path=dest)

def symlink(target, link, overwrite=False):
    if os.path.exists(link):
        if overwrite:
            print("Overwriting {}".format(link))
            os.remove(link)
        else:
            print("{} already exists".format(link))
            return

    os.symlink(target, link)

def print_attr(o):
    print("\n".join(["{}: {}".format(k, getattr(o, k)) for k in dir(o)]))

def isiter(o):
    return hasattr(o, "__iter__") and type(o) != str

def silence(f):
    def _f(*args, **kwargs):
        out_fd = os.dup(1)
        err_fd = os.dup(2)

        os.close(1)
        os.open("/dev/null", os.O_WRONLY) 
        os.close(2)
        os.open("/dev/null", os.O_WRONLY)

        out = f(*args, **kwargs)

        os.close(1)
        os.dup(out_fd) 
        os.close(2)
        os.dup(err_fd) 

        os.close(out_fd)
        os.close(err_fd)

        return out
    return _f

def import_blender(silent=True):
    def _f():
        return importlib.import_module("bpy")
    _f = silence(_f) if silent else _f
    return _f()

def import_mpl(offline=False):
    matplotlib = _import("matplotlib")
    matplotlib.use("Agg") 

    return matplotlib

def _import(module_name):
    return importlib.import_module(module_name)

def cats_from_dir(dir_):
    return [os.path.basename(d) for d in ls(dir_)]

def strsearch(regex_str, inp, typ=str):
    return_single = False

    if type(inp) == str:
        return_single = True
        inp = [inp]

    regex = re.compile(regex_str)
    out = []

    for s in inp:
        m = regex.search(s)
        if m:
            res = [typ(match) for match in m.groups()]
            out.append(res if len(res) > 1 else res[0])

    return out[0] if return_single else out


def strsearch_i(regex_str, inp):
    regex_str = regex_str.replace(r"{}", r"(\d+)")
    return strsearch(regex_str, inp, int)

def intersect(l1, l2):
    return [e for e in l1 if e in l2]

def union(l1, l2):
    return list(set(l1).union(l2))

def set_minus(l1, l2):
    return list(set(l1) - set(l2))

def runCmd(cmd, extra_vars={}, verbose=False):

    if verbose:
        print("Running {}".format(cmd))
    env = os.environ.copy()
    env.update(extra_vars)

    proc = subprocess.Popen(
        cmd,
        shell = True,
        #executable = '/bin/bash',
        stdin = None,
        stdout = subprocess.PIPE,
        stderr = subprocess.PIPE,
        env = env)


    lines = []

    while proc.poll() is None:
        line = proc.stdout.readline().decode("ascii").rstrip()
        lines.append(line)
        if verbose and line != "":
            print(line)

    return lines


def degreesToRadians(degrees):
    if isinstance(degrees, list):
        for i, _ in enumerate(degrees):
            degrees[i] = degrees[i] * 0.0174532925
    else:
        degrees = degrees * 0.0174532925

    return degrees



def standardize(X, feat_stddev_thres=None):
    """ Params:
            - X: feature set (n_samples x n_features)
            - feat_stddev_thres: minimum threshold to keep feature (column in X)
    """
    import numpy as np

    X = np.array(X, dtype=np.float64)

    mu = np.mean(X, axis=0)
    s = np.std(X, axis=0)
    if feat_stddev_thres:
        feat_ixs, = np.where(s >= feat_stddev_thres)

        X = X[:, feat_ixs]
        s = s[feat_ixs]
        mu = mu[feat_ixs]
        X = (X - mu) / s
    else:
        feat_ixs = np.arange(X.shape[1])

    return (X, mu, s, feat_ixs)


class Dict(dict):
    def __init__(self, *args, **kwargs):
        super(self.__class__, self).__init__(*args, **kwargs)
        for arg in args:
            if isinstance(arg, dict):
                for k, v in arg.items():
                    self[k] = v

        if kwargs:
            for k, v in kwargs.iteritems():
                self[k] = v

    def __getattr__(self, attr):
        return self.get(attr)

    def __setattr__(self, key, value):
        self.__setitem__(key, value)

    def __setitem__(self, key, value):
        super(self.__class__, self).__setitem__(key, value)
        self.__dict__.update({key: value})

    def __delattr__(self, item):
        self.__delitem__(item)

    def __delitem__(self, key):
        super(self.__class__, self).__delitem__(key)
        del self.__dict__[key]

    def keys_by_val(self, val):
        return [k for k,v in self.items() if v == val]

    def key_by_val(self, val):
        return self.keys_by_val(val)[0]

    def __sizeof__(self):
        total = 0
        for k,v in self.items():
            if type(v) == dict:
                v = Dict(v)
            total += v.__sizeof__()

        return total

    # for pickle
    def __getstate__(self):
        return self.__dict__

    def __setstate__(self, d):
        self.__dict__.update(d)

class RunningAvg(object):
    def __init__(self):
        self.reset()

    def reset(self):
        self.val = 0
        self.avg = 0
        self.sum = 0
        self.count = 0

    def update(self, val, n=1):
        self.val = val
        self.sum += val * n
        self.count += n
        self.avg = self.sum / self.count