@echo off
REM ============================================================
REM  CRIMSIN SCHOOL MANAGER — WINDOWS BUILD SCRIPT
REM  Run each SECTION one at a time in CMD (as Administrator)
REM  Copy the whole section, paste, press Enter.
REM ============================================================

REM ============================================================
REM  SECTION 1 — VERIFY PREREQUISITES
REM  (Install Node, PostgreSQL, Git first if not done)
REM  Download Node.js  : https://nodejs.org  (LTS)
REM  Download Postgres : https://www.postgresql.org/download/
REM  Download Git      : https://git-scm.com/downloads
REM ============================================================

node -v
npm -v
psql --version
git --version

REM ============================================================
REM  SECTION 2 — CREATE PROJECT STRUCTURE
REM ============================================================

mkdir crimsin-school-manager
cd crimsin-school-manager
mkdir backend frontend

REM ============================================================
REM  SECTION 3 — BACKEND: INIT & INSTALL PACKAGES
REM ============================================================

cd backend
npm init -y
npm install express pg bcryptjs jsonwebtoken dotenv cors helmet morgan express-validator multer nodemailer axios uuid
npm install --save-dev nodemon
mkdir src
mkdir src\controllers src\routes src\middleware src\models src\utils src\config
mkdir uploads
mkdir uploads\reports uploads\avatars

REM ============================================================
REM  SECTION 4 — CREATE .env FILE
REM  (Edit YourStrongPassword123 and email fields after creation)
REM ============================================================

(
echo PORT=5000
echo NODE_ENV=development
echo DB_HOST=localhost
echo DB_PORT=5432
echo DB_NAME=crimsin_db
echo DB_USER=postgres
echo DB_PASSWORD=YourStrongPassword123
echo JWT_SECRET=CrimsinSuperSecretKey2024XYZ
echo JWT_EXPIRES_IN=7d
echo MPESA_CONSUMER_KEY=your_mpesa_consumer_key
echo MPESA_CONSUMER_SECRET=your_mpesa_consumer_secret
echo MPESA_SHORTCODE=174379
echo MPESA_PASSKEY=bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919
echo MPESA_CALLBACK_URL=https://yourdomain.com/api/payments/mpesa/callback
echo FRONTEND_URL=http://localhost:3000
echo EMAIL_HOST=smtp.gmail.com
echo EMAIL_PORT=587
echo EMAIL_USER=your_email@gmail.com
echo EMAIL_PASS=your_app_password
) > .env

REM ============================================================
REM  SECTION 5 — UPDATE package.json SCRIPTS
REM ============================================================

node -e "const fs=require('fs');const pkg=JSON.parse(fs.readFileSync('package.json'));pkg.scripts={start:'node src/server.js',dev:'nodemon src/server.js',test:'echo No tests yet'};pkg.main='src/server.js';fs.writeFileSync('package.json',JSON.stringify(pkg,null,2));console.log('package.json updated');"

REM ============================================================
REM  SECTION 6 — CREATE DATABASE IN POSTGRESQL
REM  (Run in CMD — enter your postgres password when prompted)
REM ============================================================

psql -U postgres -c "CREATE DATABASE crimsin_db;"
psql -U postgres -c "CREATE USER crimsin_user WITH ENCRYPTED PASSWORD 'YourStrongPassword123';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE crimsin_db TO crimsin_user;"

REM ============================================================
REM  SECTION 7 — CREATE DATABASE SCHEMA FILE
REM  (Paste this entire block into CMD and press Enter)
REM ============================================================

node -e "const fs=require('fs');const sql=`-- CRIMSIN SCHOOL MANAGER DATABASE SCHEMA\nCREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";\n\nCREATE TABLE IF NOT EXISTS subscription_plans (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  name VARCHAR(100) NOT NULL,\n  price_kes DECIMAL(10,2) NOT NULL,\n  duration_days INTEGER NOT NULL DEFAULT 30,\n  features JSONB,\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS schools (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  name VARCHAR(255) NOT NULL,\n  email VARCHAR(255) UNIQUE NOT NULL,\n  phone VARCHAR(20),\n  location VARCHAR(255),\n  logo_url VARCHAR(500),\n  subscription_status VARCHAR(20) DEFAULT 'inactive' CHECK (subscription_status IN ('active','inactive','suspended')),\n  subscription_expires_at TIMESTAMP,\n  plan_id UUID REFERENCES subscription_plans(id),\n  created_at TIMESTAMP DEFAULT NOW(),\n  updated_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS users (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  name VARCHAR(255) NOT NULL,\n  email VARCHAR(255) UNIQUE NOT NULL,\n  phone VARCHAR(20),\n  password_hash VARCHAR(255) NOT NULL,\n  role VARCHAR(20) NOT NULL CHECK (role IN ('super_admin','school_admin','teacher','parent')),\n  avatar_url VARCHAR(500),\n  is_active BOOLEAN DEFAULT true,\n  last_login TIMESTAMP,\n  created_at TIMESTAMP DEFAULT NOW(),\n  updated_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS classes (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  name VARCHAR(100) NOT NULL,\n  grade_level VARCHAR(50),\n  academic_year VARCHAR(20),\n  class_teacher_id UUID REFERENCES users(id),\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS subjects (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  name VARCHAR(100) NOT NULL,\n  code VARCHAR(20),\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS class_subjects (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  class_id UUID REFERENCES classes(id) ON DELETE CASCADE,\n  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,\n  teacher_id UUID REFERENCES users(id),\n  UNIQUE(class_id, subject_id)\n);\n\nCREATE TABLE IF NOT EXISTS students (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  class_id UUID REFERENCES classes(id),\n  admission_number VARCHAR(50),\n  name VARCHAR(255) NOT NULL,\n  date_of_birth DATE,\n  gender VARCHAR(10),\n  avatar_url VARCHAR(500),\n  is_active BOOLEAN DEFAULT true,\n  created_at TIMESTAMP DEFAULT NOW(),\n  updated_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS student_parents (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  student_id UUID REFERENCES students(id) ON DELETE CASCADE,\n  parent_id UUID REFERENCES users(id) ON DELETE CASCADE,\n  relationship VARCHAR(50),\n  UNIQUE(student_id, parent_id)\n);\n\nCREATE TABLE IF NOT EXISTS attendance (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  student_id UUID REFERENCES students(id) ON DELETE CASCADE,\n  class_id UUID REFERENCES classes(id),\n  date DATE NOT NULL,\n  status VARCHAR(20) NOT NULL CHECK (status IN ('present','absent','late','excused')),\n  notes TEXT,\n  marked_by UUID REFERENCES users(id),\n  created_at TIMESTAMP DEFAULT NOW(),\n  UNIQUE(student_id, date)\n);\n\nCREATE TABLE IF NOT EXISTS exams (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  class_id UUID REFERENCES classes(id),\n  subject_id UUID REFERENCES subjects(id),\n  name VARCHAR(255) NOT NULL,\n  exam_date DATE,\n  total_marks DECIMAL(5,2),\n  term VARCHAR(20),\n  academic_year VARCHAR(20),\n  created_by UUID REFERENCES users(id),\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS marks (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  exam_id UUID REFERENCES exams(id) ON DELETE CASCADE,\n  student_id UUID REFERENCES students(id) ON DELETE CASCADE,\n  marks_obtained DECIMAL(5,2),\n  grade VARCHAR(5),\n  teacher_comment TEXT,\n  entered_by UUID REFERENCES users(id),\n  created_at TIMESTAMP DEFAULT NOW(),\n  updated_at TIMESTAMP DEFAULT NOW(),\n  UNIQUE(exam_id, student_id)\n);\n\nCREATE TABLE IF NOT EXISTS announcements (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  title VARCHAR(255) NOT NULL,\n  content TEXT NOT NULL,\n  audience VARCHAR(20) DEFAULT 'all' CHECK (audience IN ('all','parents','teachers','students')),\n  created_by UUID REFERENCES users(id),\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS messages (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  sender_id UUID REFERENCES users(id),\n  receiver_id UUID REFERENCES users(id),\n  subject VARCHAR(255),\n  content TEXT NOT NULL,\n  is_read BOOLEAN DEFAULT false,\n  parent_message_id UUID REFERENCES messages(id),\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS notifications (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  user_id UUID REFERENCES users(id) ON DELETE CASCADE,\n  type VARCHAR(50),\n  title VARCHAR(255),\n  message TEXT,\n  is_read BOOLEAN DEFAULT false,\n  data JSONB,\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nCREATE TABLE IF NOT EXISTS payments (\n  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),\n  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,\n  amount DECIMAL(10,2) NOT NULL,\n  currency VARCHAR(10) DEFAULT 'KES',\n  payment_method VARCHAR(50) DEFAULT 'mpesa',\n  mpesa_transaction_id VARCHAR(100),\n  mpesa_phone VARCHAR(20),\n  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','completed','failed','refunded')),\n  subscription_months INTEGER DEFAULT 1,\n  paid_at TIMESTAMP,\n  created_at TIMESTAMP DEFAULT NOW()\n);\n\nINSERT INTO subscription_plans (name, price_kes, duration_days, features)\nVALUES ('Standard', 3000.00, 30, '{\"students\": \"unlimited\", \"teachers\": \"unlimited\", \"sms\": false, \"reports\": true}')\nON CONFLICT DO NOTHING;\n\nCREATE INDEX IF NOT EXISTS idx_users_school ON users(school_id);\nCREATE INDEX IF NOT EXISTS idx_students_school ON students(school_id);\nCREATE INDEX IF NOT EXISTS idx_students_class ON students(class_id);\nCREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);\nCREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(date);\nCREATE INDEX IF NOT EXISTS idx_marks_student ON marks(student_id);\nCREATE INDEX IF NOT EXISTS idx_marks_exam ON marks(exam_id);\nCREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);\nCREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);\n`;fs.mkdirSync('src/config',{recursive:true});fs.writeFileSync('src/config/schema.sql',sql);console.log('schema.sql created');"

REM ============================================================
REM  SECTION 8 — RUN SCHEMA INTO DATABASE
REM ============================================================

psql -U postgres -d crimsin_db -f src/config/schema.sql

REM ============================================================
REM  SECTION 9 — CREATE src/config/db.js
REM ============================================================

node -e "const fs=require('fs');fs.writeFileSync('src/config/db.js',`const { Pool } = require('pg');\nrequire('dotenv').config();\n\nconst pool = new Pool({\n  host: process.env.DB_HOST,\n  port: process.env.DB_PORT,\n  database: process.env.DB_NAME,\n  user: process.env.DB_USER,\n  password: process.env.DB_PASSWORD,\n  max: 20,\n  idleTimeoutMillis: 30000,\n  connectionTimeoutMillis: 2000,\n});\n\npool.on('error', (err) => {\n  console.error('Unexpected error on idle client', err);\n  process.exit(-1);\n});\n\nmodule.exports = {\n  query: (text, params) => pool.query(text, params),\n  getClient: () => pool.connect(),\n};\n`);console.log('db.js created');"

REM ============================================================
REM  SECTION 10 — CREATE src/middleware/auth.js
REM ============================================================

node -e "const fs=require('fs');fs.writeFileSync('src/middleware/auth.js',`const jwt = require('jsonwebtoken');\nconst db = require('../config/db');\n\nconst authenticate = async (req, res, next) => {\n  try {\n    const token = req.headers.authorization?.split(' ')[1];\n    if (!token) return res.status(401).json({ success: false, message: 'No token provided' });\n    const decoded = jwt.verify(token, process.env.JWT_SECRET);\n    const result = await db.query('SELECT * FROM users WHERE id = \$1 AND is_active = true', [decoded.id]);\n    if (!result.rows.length) return res.status(401).json({ success: false, message: 'User not found' });\n    req.user = result.rows[0];\n    next();\n  } catch (err) {\n    return res.status(401).json({ success: false, message: 'Invalid token' });\n  }\n};\n\nconst authorize = (...roles) => (req, res, next) => {\n  if (!roles.includes(req.user.role)) {\n    return res.status(403).json({ success: false, message: 'Access denied' });\n  }\n  next();\n};\n\nmodule.exports = { authenticate, authorize };\n`);console.log('auth.js middleware created');"

REM ============================================================
REM  SECTION 11 — CREATE src/controllers/authController.js
REM ============================================================

node -e "const fs=require('fs');fs.writeFileSync('src/controllers/authController.js',`const bcrypt = require('bcryptjs');\nconst jwt = require('jsonwebtoken');\nconst db = require('../config/db');\n\nconst generateToken = (user) => jwt.sign(\n  { id: user.id, role: user.role, school_id: user.school_id },\n  process.env.JWT_SECRET,\n  { expiresIn: process.env.JWT_EXPIRES_IN }\n);\n\nexports.register = async (req, res) => {\n  try {\n    const { schoolName, schoolEmail, schoolPhone, schoolLocation, adminName, adminEmail, adminPassword } = req.body;\n    const existingSchool = await db.query('SELECT id FROM schools WHERE email = \$1', [schoolEmail]);\n    if (existingSchool.rows.length) return res.status(400).json({ success: false, message: 'School already registered' });\n    const planResult = await db.query('SELECT id FROM subscription_plans LIMIT 1');\n    const planId = planResult.rows[0]?.id;\n    const schoolResult = await db.query(\n      'INSERT INTO schools (name, email, phone, location, plan_id, subscription_status) VALUES (\$1, \$2, \$3, \$4, \$5, \$6) RETURNING *',\n      [schoolName, schoolEmail, schoolPhone, schoolLocation, planId, 'inactive']\n    );\n    const school = schoolResult.rows[0];\n    const passwordHash = await bcrypt.hash(adminPassword, 12);\n    const adminResult = await db.query(\n      'INSERT INTO users (school_id, name, email, phone, password_hash, role) VALUES (\$1, \$2, \$3, \$4, \$5, \$6) RETURNING *',\n      [school.id, adminName, adminEmail, schoolPhone, passwordHash, 'school_admin']\n    );\n    const token = generateToken(adminResult.rows[0]);\n    res.status(201).json({ success: true, message: 'School registered successfully', token, user: { ...adminResult.rows[0], password_hash: undefined }, school });\n  } catch (err) {\n    console.error(err);\n    res.status(500).json({ success: false, message: 'Registration failed', error: err.message });\n  }\n};\n\nexports.login = async (req, res) => {\n  try {\n    const { email, password } = req.body;\n    const result = await db.query('SELECT u.*, s.subscription_status, s.name as school_name FROM users u LEFT JOIN schools s ON u.school_id = s.id WHERE u.email = \$1 AND u.is_active = true', [email]);\n    if (!result.rows.length) return res.status(401).json({ success: false, message: 'Invalid credentials' });\n    const user = result.rows[0];\n    const valid = await bcrypt.compare(password, user.password_hash);\n    if (!valid) return res.status(401).json({ success: false, message: 'Invalid credentials' });\n    await db.query('UPDATE users SET last_login = NOW() WHERE id = \$1', [user.id]);\n    const token = generateToken(user);\n    const { password_hash, ...safeUser } = user;\n    res.json({ success: true, token, user: safeUser });\n  } catch (err) {\n    res.status(500).json({ success: false, message: 'Login failed', error: err.message });\n  }\n};\n\nexports.me = async (req, res) => {\n  const { password_hash, ...safeUser } = req.user;\n  res.json({ success: true, user: safeUser });\n};\n`);console.log('authController.js created');"

REM ============================================================
REM  SECTION 12 — CREATE src/controllers/mpesaController.js
REM ============================================================

node -e "const fs=require('fs');fs.writeFileSync('src/controllers/mpesaController.js',`const axios = require('axios');\nconst db = require('../config/db');\n\nconst getAccessToken = async () => {\n  const auth = Buffer.from(\`\${process.env.MPESA_CONSUMER_KEY}:\${process.env.MPESA_CONSUMER_SECRET}\`).toString('base64');\n  const res = await axios.get('https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials', {\n    headers: { Authorization: \`Basic \${auth}\` }\n  });\n  return res.data.access_token;\n};\n\nexports.stkPush = async (req, res) => {\n  try {\n    const { phone, amount, schoolId } = req.body;\n    const token = await getAccessToken();\n    const timestamp = new Date().toISOString().replace(/[-T:\\.Z]/g, '').slice(0, 14);\n    const password = Buffer.from(\`\${process.env.MPESA_SHORTCODE}\${process.env.MPESA_PASSKEY}\${timestamp}\`).toString('base64');\n    const formattedPhone = phone.startsWith('0') ? \`254\${phone.slice(1)}\` : phone;\n    const response = await axios.post('https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest', {\n      BusinessShortCode: process.env.MPESA_SHORTCODE,\n      Password: password,\n      Timestamp: timestamp,\n      TransactionType: 'CustomerPayBillOnline',\n      Amount: amount || 3000,\n      PartyA: formattedPhone,\n      PartyB: process.env.MPESA_SHORTCODE,\n      PhoneNumber: formattedPhone,\n      CallBackURL: process.env.MPESA_CALLBACK_URL,\n      AccountReference: \`CRIMSIN-\${schoolId}\`,\n      TransactionDesc: 'CRIMSIN School Subscription'\n    }, { headers: { Authorization: \`Bearer \${token}\` } });\n    await db.query('INSERT INTO payments (school_id, amount, mpesa_phone, status) VALUES (\$1, \$2, \$3, \$4)', [schoolId, amount || 3000, phone, 'pending']);\n    res.json({ success: true, message: 'STK Push sent. Check your phone.', data: response.data });\n  } catch (err) {\n    console.error(err.response?.data || err.message);\n    res.status(500).json({ success: false, message: 'Payment initiation failed', error: err.response?.data || err.message });\n  }\n};\n\nexports.callback = async (req, res) => {\n  try {\n    const callback = req.body?.Body?.stkCallback;\n    if (callback?.ResultCode === 0) {\n      const txId = callback.CallbackMetadata.Item.find(i => i.Name === 'MpesaReceiptNumber')?.Value;\n      const phone = callback.CallbackMetadata.Item.find(i => i.Name === 'PhoneNumber')?.Value;\n      await db.query('UPDATE payments SET status = \$1, mpesa_transaction_id = \$2, paid_at = NOW() WHERE mpesa_phone LIKE \$3 AND status = \$4', ['completed', txId, \`%\${String(phone).slice(-9)}\`, 'pending']);\n      const schoolIdRef = callback.AccountReference?.split('-')[1];\n      if (schoolIdRef) {\n        await db.query(\"UPDATE schools SET subscription_status = \$1, subscription_expires_at = NOW() + INTERVAL '30 days' WHERE id = \$2\", ['active', schoolIdRef]);\n      }\n    }\n    res.json({ ResultCode: 0, ResultDesc: 'Success' });\n  } catch (err) {\n    console.error(err);\n    res.json({ ResultCode: 0, ResultDesc: 'Processed' });\n  }\n};\n`);console.log('mpesaController.js created');"

REM ============================================================
REM  SECTION 13 — CREATE ROUTES
REM ============================================================

node -e "const fs=require('fs');fs.writeFileSync('src/routes/auth.js',`const router = require('express').Router();\nconst { register, login, me } = require('../controllers/authController');\nconst { authenticate } = require('../middleware/auth');\nrouter.post('/register', register);\nrouter.post('/login', login);\nrouter.get('/me', authenticate, me);\nmodule.exports = router;\n`);console.log('routes/auth.js created');"

node -e "const fs=require('fs');fs.writeFileSync('src/routes/payments.js',`const router = require('express').Router();\nconst { stkPush, callback } = require('../controllers/mpesaController');\nconst { authenticate } = require('../middleware/auth');\nrouter.post('/mpesa/stk', authenticate, stkPush);\nrouter.post('/mpesa/callback', callback);\nmodule.exports = router;\n`);console.log('routes/payments.js created');"

node -e "const fs=require('fs');fs.writeFileSync('src/routes/dashboard.js',`const router = require('express').Router();\nconst db = require('../config/db');\nconst { authenticate } = require('../middleware/auth');\nrouter.get('/stats', authenticate, async (req, res) => {\n  try {\n    const { school_id } = req.user;\n    const [students, teachers, classes, pending] = await Promise.all([\n      db.query('SELECT COUNT(*) FROM students WHERE school_id = \$1 AND is_active = true', [school_id]),\n      db.query('SELECT COUNT(*) FROM users WHERE school_id = \$1 AND role = \$2', [school_id, 'teacher']),\n      db.query('SELECT COUNT(*) FROM classes WHERE school_id = \$1', [school_id]),\n      db.query('SELECT COUNT(*) FROM notifications WHERE user_id = \$1 AND is_read = false', [req.user.id])\n    ]);\n    res.json({ success: true, stats: { totalStudents: parseInt(students.rows[0].count), totalTeachers: parseInt(teachers.rows[0].count), totalClasses: parseInt(classes.rows[0].count), pendingNotifications: parseInt(pending.rows[0].count) } });\n  } catch (err) {\n    res.status(500).json({ success: false, error: err.message });\n  }\n});\nmodule.exports = router;\n`);console.log('routes/dashboard.js created');"

REM ============================================================
REM  SECTION 14 — CREATE src/server.js (MAIN ENTRY POINT)
REM ============================================================

node -e "const fs=require('fs');fs.writeFileSync('src/server.js',`require('dotenv').config();\nconst express = require('express');\nconst cors = require('cors');\nconst helmet = require('helmet');\nconst morgan = require('morgan');\nconst path = require('path');\nconst app = express();\napp.use(helmet());\napp.use(cors({ origin: process.env.FRONTEND_URL, credentials: true }));\napp.use(morgan('combined'));\napp.use(express.json({ limit: '10mb' }));\napp.use(express.urlencoded({ extended: true }));\napp.use('/uploads', express.static(path.join(__dirname, '../uploads')));\napp.use('/api/auth', require('./routes/auth'));\napp.use('/api/payments', require('./routes/payments'));\napp.use('/api/dashboard', require('./routes/dashboard'));\napp.get('/health', (req, res) => res.json({ status: 'OK', timestamp: new Date().toISOString(), service: 'CRIMSIN API' }));\napp.use((req, res) => res.status(404).json({ success: false, message: 'Route not found' }));\napp.use((err, req, res, next) => { console.error(err.stack); res.status(500).json({ success: false, message: 'Internal server error' }); });\nconst PORT = process.env.PORT || 5000;\napp.listen(PORT, () => { console.log('CRIMSIN API running on port ' + PORT); });\n`);console.log('server.js created');"

REM ============================================================
REM  SECTION 15 — START BACKEND (TERMINAL 1)
REM  Open a new CMD window, navigate to backend, run:
REM     cd crimsin-school-manager\backend && npm run dev
REM  You should see: CRIMSIN API running on port 5000
REM  Test: open browser -> http://localhost:5000/health
REM ============================================================

REM npm run dev

REM ============================================================
REM  SECTION 16 — SETUP FRONTEND (Open a NEW CMD window)
REM  Navigate to the frontend folder first:
REM     cd crimsin-school-manager\frontend
REM ============================================================

cd ..\frontend
npx create-next-app@latest . --typescript=false --tailwind=true --eslint=false --app=false --src-dir=false --import-alias="@/*" --yes
npm install axios react-hot-toast recharts lucide-react @radix-ui/react-dialog @radix-ui/react-dropdown-menu date-fns

REM ============================================================
REM  SECTION 17 — FRONTEND .env.local
REM ============================================================

echo NEXT_PUBLIC_API_URL=http://localhost:5000/api > .env.local

REM ============================================================
REM  SECTION 18 — CREATE FRONTEND FOLDERS
REM ============================================================

mkdir lib utils components
mkdir components\ui components\dashboard components\auth

REM ============================================================
REM  SECTION 19 — CREATE lib/api.js
REM ============================================================

node -e "const fs=require('fs');fs.mkdirSync('lib',{recursive:true});fs.writeFileSync('lib/api.js',`import axios from 'axios';\n\nconst api = axios.create({\n  baseURL: process.env.NEXT_PUBLIC_API_URL,\n  timeout: 15000,\n});\n\napi.interceptors.request.use((config) => {\n  if (typeof window !== 'undefined') {\n    const token = localStorage.getItem('crimsin_token');\n    if (token) config.headers.Authorization = \`Bearer \${token}\`;\n  }\n  return config;\n});\n\napi.interceptors.response.use(\n  (response) => response.data,\n  (error) => {\n    if (error.response?.status === 401 && typeof window !== 'undefined') {\n      localStorage.removeItem('crimsin_token');\n      localStorage.removeItem('crimsin_user');\n      window.location.href = '/login';\n    }\n    return Promise.reject(error.response?.data || error);\n  }\n);\n\nexport default api;\n`);console.log('lib/api.js created');"

REM ============================================================
REM  SECTION 20 — CREATE utils/AuthContext.js
REM ============================================================

node -e "const fs=require('fs');fs.mkdirSync('utils',{recursive:true});fs.writeFileSync('utils/AuthContext.js',`import { createContext, useContext, useState, useEffect } from 'react';\nimport api from '../lib/api';\n\nconst AuthContext = createContext(null);\n\nexport const AuthProvider = ({ children }) => {\n  const [user, setUser] = useState(null);\n  const [loading, setLoading] = useState(true);\n\n  useEffect(() => {\n    const token = localStorage.getItem('crimsin_token');\n    const savedUser = localStorage.getItem('crimsin_user');\n    if (token && savedUser) {\n      setUser(JSON.parse(savedUser));\n      api.get('/auth/me').then(res => {\n        setUser(res.user);\n        localStorage.setItem('crimsin_user', JSON.stringify(res.user));\n      }).catch(() => logout());\n    }\n    setLoading(false);\n  }, []);\n\n  const login = async (email, password) => {\n    const res = await api.post('/auth/login', { email, password });\n    localStorage.setItem('crimsin_token', res.token);\n    localStorage.setItem('crimsin_user', JSON.stringify(res.user));\n    setUser(res.user);\n    return res;\n  };\n\n  const logout = () => {\n    localStorage.removeItem('crimsin_token');\n    localStorage.removeItem('crimsin_user');\n    setUser(null);\n  };\n\n  return (\n    <AuthContext.Provider value={{ user, loading, login, logout }}>\n      {children}\n    </AuthContext.Provider>\n  );\n};\n\nexport const useAuth = () => useContext(AuthContext);\n`);console.log('AuthContext.js created');"

REM ============================================================
REM  SECTION 21 — CREATE pages/_app.js
REM ============================================================

node -e "const fs=require('fs');fs.mkdirSync('pages',{recursive:true});fs.writeFileSync('pages/_app.js',`import '../styles/globals.css';\nimport { AuthProvider } from '../utils/AuthContext';\nimport { Toaster } from 'react-hot-toast';\n\nexport default function App({ Component, pageProps }) {\n  return (\n    <AuthProvider>\n      <Component {...pageProps} />\n      <Toaster position=\"top-right\" toastOptions={{ duration: 4000 }} />\n    </AuthProvider>\n  );\n}\n`);console.log('_app.js created');"

REM ============================================================
REM  SECTION 22 — CREATE pages/index.js (Landing Page)
REM ============================================================

node -e "const fs=require('fs');const content=`import Head from 'next/head';\nimport Link from 'next/link';\nimport { BookOpen, Users, BarChart3, Bell, MessageCircle, Shield, CheckCircle, Star, Phone } from 'lucide-react';\n\nexport default function Home() {\n  const features = [\n    { icon: <Users size={28} />, title: 'Student Management', desc: 'Manage all students, classes, and academic records from one place.' },\n    { icon: <BarChart3 size={28} />, title: 'Grades and Marks', desc: 'Teachers upload results instantly. Parents see them in real-time.' },\n    { icon: <Bell size={28} />, title: 'Smart Notifications', desc: 'Parents get instant alerts for absences, results, and announcements.' },\n    { icon: <MessageCircle size={28} />, title: 'Direct Messaging', desc: 'Seamless communication between parents and teachers.' },\n    { icon: <BarChart3 size={28} />, title: 'Attendance Tracking', desc: 'Daily attendance recorded and parents notified immediately.' },\n    { icon: <Shield size={28} />, title: 'Secure and Reliable', desc: 'Bank-grade security. Your school data is always safe.' },\n  ];\n  return (\n    <>\n      <Head>\n        <title>CRIMSIN School Manager</title>\n        <meta name=\"description\" content=\"Kenya's most trusted school management platform.\" />\n        <link href=\"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap\" rel=\"stylesheet\" />\n      </Head>\n      <style>{\`\n        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', sans-serif; }\n        body { background: #f8fafc; color: #1e293b; }\n        nav { background: #fff; border-bottom: 1px solid #e2e8f0; padding: 16px 40px; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }\n        .logo { font-size: 22px; font-weight: 800; color: #1d4ed8; letter-spacing: -0.5px; }\n        .logo span { color: #f59e0b; }\n        .nav-links { display: flex; gap: 16px; align-items: center; }\n        .btn-outline { padding: 8px 20px; border: 2px solid #1d4ed8; color: #1d4ed8; border-radius: 8px; text-decoration: none; font-weight: 600; transition: all .2s; }\n        .btn-outline:hover { background: #1d4ed8; color: #fff; }\n        .btn-primary { padding: 8px 20px; background: #1d4ed8; color: #fff; border-radius: 8px; text-decoration: none; font-weight: 600; transition: all .2s; }\n        .btn-primary:hover { background: #1e40af; transform: translateY(-1px); box-shadow: 0 4px 12px rgba(29,78,216,0.3); }\n        .hero { background: linear-gradient(135deg, #1d4ed8 0%, #1e40af 50%, #1e3a8a 100%); color: #fff; padding: 100px 40px; text-align: center; position: relative; overflow: hidden; }\n        .hero h1 { font-size: 54px; font-weight: 800; line-height: 1.1; margin-bottom: 20px; letter-spacing: -1px; }\n        .hero h1 span { color: #fbbf24; }\n        .hero p { font-size: 20px; color: rgba(255,255,255,0.85); max-width: 600px; margin: 0 auto 40px; line-height: 1.6; }\n        .hero-cta { display: flex; gap: 16px; justify-content: center; flex-wrap: wrap; }\n        .btn-hero-primary { padding: 16px 36px; background: #f59e0b; color: #1e3a8a; border-radius: 10px; text-decoration: none; font-weight: 700; font-size: 16px; transition: all .2s; }\n        .btn-hero-primary:hover { background: #fbbf24; transform: translateY(-2px); box-shadow: 0 8px 24px rgba(245,158,11,0.4); }\n        .btn-hero-outline { padding: 16px 36px; border: 2px solid rgba(255,255,255,0.5); color: #fff; border-radius: 10px; text-decoration: none; font-weight: 600; font-size: 16px; transition: all .2s; }\n        .btn-hero-outline:hover { border-color: #fff; background: rgba(255,255,255,0.1); }\n        .badge { display: inline-flex; align-items: center; gap: 8px; background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.25); padding: 8px 18px; border-radius: 50px; font-size: 14px; margin-bottom: 28px; }\n        .stats { background: #fff; padding: 50px 40px; display: flex; justify-content: center; gap: 60px; flex-wrap: wrap; border-bottom: 1px solid #e2e8f0; }\n        .stat { text-align: center; }\n        .stat-number { font-size: 40px; font-weight: 800; color: #1d4ed8; }\n        .stat-label { color: #64748b; font-size: 14px; margin-top: 4px; }\n        .section { padding: 80px 40px; max-width: 1200px; margin: 0 auto; }\n        .section-title { font-size: 38px; font-weight: 800; text-align: center; margin-bottom: 12px; letter-spacing: -0.5px; }\n        .section-subtitle { text-align: center; color: #64748b; font-size: 18px; margin-bottom: 56px; }\n        .features-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 28px; }\n        .feature-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 16px; padding: 32px; transition: all .3s; }\n        .feature-card:hover { transform: translateY(-4px); box-shadow: 0 20px 40px rgba(0,0,0,0.08); border-color: #bfdbfe; }\n        .feature-icon { width: 56px; height: 56px; background: #eff6ff; border-radius: 14px; display: flex; align-items: center; justify-content: center; color: #1d4ed8; margin-bottom: 20px; }\n        .feature-card h3 { font-size: 19px; font-weight: 700; margin-bottom: 10px; }\n        .feature-card p { color: #64748b; line-height: 1.6; }\n        .pricing-section { background: #f0f9ff; padding: 80px 40px; }\n        .pricing-card { background: #fff; border: 2px solid #1d4ed8; border-radius: 20px; padding: 48px; max-width: 420px; margin: 0 auto; text-align: center; box-shadow: 0 20px 60px rgba(29,78,216,0.1); }\n        .price { font-size: 56px; font-weight: 800; color: #1d4ed8; }\n        .price-sub { color: #64748b; font-size: 16px; margin-bottom: 32px; }\n        .price-features { list-style: none; margin-bottom: 36px; }\n        .price-features li { padding: 10px 0; display: flex; align-items: center; gap: 10px; color: #374151; border-bottom: 1px solid #f1f5f9; font-size: 15px; }\n        .price-features li:last-child { border-bottom: none; }\n        .cta-section { background: linear-gradient(135deg, #1d4ed8, #7c3aed); padding: 80px 40px; text-align: center; color: #fff; }\n        .cta-section h2 { font-size: 42px; font-weight: 800; margin-bottom: 16px; }\n        .cta-section p { font-size: 18px; opacity: .85; margin-bottom: 36px; }\n        footer { background: #0f172a; color: #94a3b8; padding: 40px; text-align: center; }\n        footer .logo-footer { font-size: 20px; font-weight: 800; color: #fff; margin-bottom: 12px; }\n      \`}</style>\n      <nav>\n        <div className=\"logo\">CRIM<span>SIN</span></div>\n        <div className=\"nav-links\">\n          <a href=\"#features\" style={{textDecoration:'none',color:'#475569',fontWeight:500}}>Features</a>\n          <a href=\"#pricing\" style={{textDecoration:'none',color:'#475569',fontWeight:500}}>Pricing</a>\n          <Link href=\"/login\" className=\"btn-outline\">Sign In</Link>\n          <Link href=\"/register\" className=\"btn-primary\">Get Started</Link>\n        </div>\n      </nav>\n      <section className=\"hero\">\n        <div className=\"badge\">Trusted by Schools Across Kenya</div>\n        <h1>Manage Your School <span>Smarter</span>, Not Harder</h1>\n        <p>The all-in-one school management platform that connects administrators, teachers, and parents in real time.</p>\n        <div className=\"hero-cta\">\n          <Link href=\"/register\" className=\"btn-hero-primary\">Start Free Trial</Link>\n          <a href=\"#features\" className=\"btn-hero-outline\">See How It Works</a>\n        </div>\n      </section>\n      <div className=\"stats\">\n        <div className=\"stat\"><div className=\"stat-number\">500+</div><div className=\"stat-label\">Schools Registered</div></div>\n        <div className=\"stat\"><div className=\"stat-number\">50K+</div><div className=\"stat-label\">Students Managed</div></div>\n        <div className=\"stat\"><div className=\"stat-number\">99.9%</div><div className=\"stat-label\">Uptime Guarantee</div></div>\n        <div className=\"stat\"><div className=\"stat-number\">KSh 3K</div><div className=\"stat-label\">Per Month Only</div></div>\n      </div>\n      <section id=\"features\" className=\"section\">\n        <h2 className=\"section-title\">Everything Your School Needs</h2>\n        <p className=\"section-subtitle\">From registration to graduation — we handle every step.</p>\n        <div className=\"features-grid\">\n          {features.map((f, i) => (\n            <div key={i} className=\"feature-card\">\n              <div className=\"feature-icon\">{f.icon}</div>\n              <h3>{f.title}</h3>\n              <p>{f.desc}</p>\n            </div>\n          ))}\n        </div>\n      </section>\n      <div id=\"pricing\" className=\"pricing-section\">\n        <div style={{maxWidth:1200,margin:'0 auto'}}>\n          <h2 className=\"section-title\">Simple, Transparent Pricing</h2>\n          <p className=\"section-subtitle\">One plan. Everything included. No hidden fees.</p>\n          <div className=\"pricing-card\">\n            <div className=\"price\">KSh 3,000</div>\n            <div className=\"price-sub\">per school / per month via M-Pesa</div>\n            <ul className=\"price-features\">\n              {['Unlimited students and teachers','Real-time parent notifications','Grade and attendance tracking','Teacher-parent messaging','School announcements','Monthly reports and analytics','Priority support','Free setup assistance'].map((f,i) => (\n                <li key={i}><CheckCircle size={18} style={{color:'#10b981',flexShrink:0}} /> {f}</li>\n              ))}\n            </ul>\n            <Link href=\"/register\" className=\"btn-primary\" style={{display:'block',padding:'16px',fontSize:'16px',borderRadius:10,textAlign:'center'}}>Register Your School</Link>\n          </div>\n        </div>\n      </div>\n      <section className=\"cta-section\">\n        <h2>Ready to Transform Your School?</h2>\n        <p>Join hundreds of Kenyan schools already using CRIMSIN to stay connected.</p>\n        <Link href=\"/register\" className=\"btn-hero-primary\">Get Started Today</Link>\n      </section>\n      <footer>\n        <div className=\"logo-footer\">CRIMSIN School Manager</div>\n        <p>2024 CRIMSIN. Built for Kenyan Schools. Powered by M-Pesa.</p>\n      </footer>\n    </>\n  );\n}\n`;fs.writeFileSync('pages/index.js',content);console.log('pages/index.js created');"

REM ============================================================
REM  SECTION 23 — CREATE pages/login.js
REM ============================================================

node -e "const fs=require('fs');fs.writeFileSync('pages/login.js',`import { useState } from 'react';\nimport Link from 'next/link';\nimport { useRouter } from 'next/router';\nimport { useAuth } from '../utils/AuthContext';\nimport toast from 'react-hot-toast';\n\nexport default function Login() {\n  const { login } = useAuth();\n  const router = useRouter();\n  const [form, setForm] = useState({ email: '', password: '' });\n  const [loading, setLoading] = useState(false);\n\n  const handleSubmit = async (e) => {\n    e.preventDefault();\n    setLoading(true);\n    try {\n      const res = await login(form.email, form.password);\n      toast.success('Welcome back, ' + res.user.name + '!');\n      const redirects = { super_admin: '/super-admin', school_admin: '/admin', teacher: '/teacher', parent: '/parent' };\n      router.push(redirects[res.user.role] || '/admin');\n    } catch (err) {\n      toast.error(err.message || 'Login failed');\n    } finally {\n      setLoading(false);\n    }\n  };\n\n  return (\n    <div style={{minHeight:'100vh',background:'linear-gradient(135deg, #1d4ed8, #1e3a8a)',display:'flex',alignItems:'center',justifyContent:'center',padding:20,fontFamily:'Inter, sans-serif'}}>\n      <style>{\`@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');\`}</style>\n      <div style={{background:'#fff',borderRadius:20,padding:48,width:'100%',maxWidth:420,boxShadow:'0 20px 60px rgba(0,0,0,0.2)'}}>\n        <div style={{textAlign:'center',marginBottom:36}}>\n          <div style={{fontSize:26,fontWeight:800,color:'#1d4ed8',marginBottom:8}}>CRIM<span style={{color:'#f59e0b'}}>SIN</span></div>\n          <h1 style={{fontSize:22,fontWeight:700,marginBottom:6}}>Welcome Back</h1>\n          <p style={{color:'#64748b',fontSize:14}}>Sign in to your school dashboard</p>\n        </div>\n        <form onSubmit={handleSubmit}>\n          {[{label:'Email Address',name:'email',type:'email'},{label:'Password',name:'password',type:'password'}].map(field => (\n            <div key={field.name} style={{marginBottom:18}}>\n              <label style={{display:'block',fontWeight:600,fontSize:13,color:'#374151',marginBottom:6}}>{field.label}</label>\n              <input\n                type={field.type}\n                value={form[field.name]}\n                onChange={e => setForm({...form,[field.name]:e.target.value})}\n                required\n                placeholder={field.label}\n                style={{width:'100%',padding:'12px 14px',border:'1.5px solid #e2e8f0',borderRadius:8,fontSize:15,outline:'none',boxSizing:'border-box'}}\n              />\n            </div>\n          ))}\n          <button type=\"submit\" disabled={loading}\n            style={{width:'100%',padding:'14px',background:loading?'#93c5fd':'#1d4ed8',color:'#fff',border:'none',borderRadius:8,fontSize:16,fontWeight:700,cursor:loading?'not-allowed':'pointer',marginTop:8}}>\n            {loading ? 'Signing in...' : 'Sign In'}\n          </button>\n        </form>\n        <p style={{textAlign:'center',marginTop:20,color:'#64748b',fontSize:14}}>\n          New school? <Link href=\"/register\" style={{color:'#1d4ed8',fontWeight:600}}>Register here</Link>\n        </p>\n      </div>\n    </div>\n  );\n}\n`);console.log('pages/login.js created');"

REM ============================================================
REM  SECTION 24 — START FRONTEND (run in Terminal 2)
REM  Make sure backend is running in Terminal 1 first!
REM ============================================================

REM npm run dev

REM ============================================================
REM  SECTION 25 — TEST THE API (run in any CMD window)
REM ============================================================

curl http://localhost:5000/health

curl -X POST http://localhost:5000/api/auth/register -H "Content-Type: application/json" -d "{\"schoolName\":\"Test School\",\"schoolEmail\":\"test@school.com\",\"schoolPhone\":\"0712345678\",\"schoolLocation\":\"Nairobi\",\"adminName\":\"John Admin\",\"adminEmail\":\"admin@test.com\",\"adminPassword\":\"Admin1234!\"}"

REM ============================================================
REM  SECTION 26 — PRODUCTION: BUILD FRONTEND
REM ============================================================

cd ..\frontend
npm run build
REM npm start

REM ============================================================
REM  SECTION 27 — PRODUCTION: PM2 PROCESS MANAGER (backend)
REM ============================================================

npm install -g pm2
cd ..\backend
pm2 start src/server.js --name "crimsin-api"
pm2 save
pm2 startup

REM ============================================================
REM  SECTION 28 — DEPLOY TO RAILWAY (easiest cloud option)
REM ============================================================

npm install -g @railway/cli
railway login

REM Backend:
cd ..\backend
railway init
railway up

REM Frontend:
cd ..\frontend
railway init
railway up

REM Then go to https://railway.app and set all .env variables in the dashboard

REM ============================================================
REM  QUICK REFERENCE
REM  Start dev (2 terminals):
REM    Terminal 1: cd crimsin-school-manager\backend && npm run dev
REM    Terminal 2: cd crimsin-school-manager\frontend && npm run dev
REM
REM  Frontend : http://localhost:3000
REM  Backend  : http://localhost:5000
REM  Health   : http://localhost:5000/health
REM
REM  DB backup:
REM    pg_dump -U postgres crimsin_db > backup.sql
REM  DB restore:
REM    psql -U postgres crimsin_db < backup.sql
REM
REM  M-Pesa sandbox test phone: 254708374149
REM  Shortcode: 174379
REM  Get keys: https://developer.safaricom.co.ke
REM ============================================================
