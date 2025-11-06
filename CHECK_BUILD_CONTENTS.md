# Check Build Contents

## Commands to Run

### Step 1: List all files in build/web

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# List all files and directories
ls -la build/web/

# List files with sizes
ls -lh build/web/

# Find all .js files
find build/web -name "*.js" -type f

# Find all files recursively
find build/web -type f | head -30
```

### Step 2: Check for main.dart.js (might be compressed)

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check for main.dart.js
ls -la build/web/main.dart.js 2>/dev/null || echo "main.dart.js not found"

# Check for compressed version
ls -la build/web/main.dart.js.gz 2>/dev/null || echo "main.dart.js.gz not found"

# Check for any main.dart files
find build/web -name "*main.dart*" -type f
```

### Step 3: Check index.html to see what it references

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# View index.html
cat build/web/index.html

# Check what script files it references
grep -i "\.js" build/web/index.html
```

### Step 4: Check if build is complete

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Count files in build/web
find build/web -type f | wc -l

# List directory structure
tree build/web/ 2>/dev/null || find build/web -type f | head -20
```

