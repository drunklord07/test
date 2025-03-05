# test

**Syncing Git Repository Between Two Laptops**

### **Steps to Sync Changes**

#### **1. Check Repository Status**
Open a terminal inside your Git repository (`test`) and run:
```bash
git status
```
This will show any new or modified files.

#### **2. Add the New Folder to Git**
To track the `iam` folder, run:
```bash
git add iam
```
Or, to add all changes:
```bash
git add .
```

#### **3. Commit the Changes**
Save the changes with a commit message:
```bash
git commit -m "Added iam folder"
```

#### **4. Push to GitHub**
Send the updates to your remote repository:
```bash
git push origin main
```
*(If your repo uses `master` instead of `main`, replace `main` with `master`.)*

#### **5. Verify on GitHub**
Go to **https://github.com/yourusername/test** and check if the `iam` folder appears.

#### **6. Pull Changes on Laptop 2**
On your second laptop, navigate to the repository folder and run:
```bash
git pull origin main
```
Now, the `iam` folder and any other changes will be synced!

---

### **Additional Notes:**
- Always run `git pull origin main` before making changes to keep everything updated.
- Use `git status` to check which files are modified or untracked.
- If you want to push frequently, consider using:
  ```bash
  git commit -am "Quick update"
  git push origin main
  ```
  *(The `-a` flag stages all modified files automatically.)*

Now your two laptops are perfectly in sync using Git! 🚀

