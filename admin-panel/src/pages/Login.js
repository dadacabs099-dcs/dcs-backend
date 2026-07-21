import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  Box,
  Paper,
  TextField,
  Button,
  Typography,
  Grid,
  Link as MuiLink,
  Alert,
  CircularProgress,
  InputAdornment,
  IconButton,
} from '@mui/material';
import {
  Lock as LockIcon,
  Visibility as VisibilityIcon,
  VisibilityOff as VisibilityOffIcon,
  Email as EmailIcon,
} from '@mui/icons-material';
import TranslatedText from '../components/TranslatedText';

function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      setError('');
      setLoading(true);
      await login(email, password);
      navigate('/');
    } catch (error) {
      setError(error.message || 'Invalid email or password');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: 'background.default', p: 2 }}>
      <Paper elevation={3} sx={{ p: 4, maxWidth: 450, width: '100%' }}>
        <Box sx={{ textAlign: 'center', mb: 4 }}>
          <Box
            component="img"
            src="/DCS_Logo.png"
            alt="Dada Cabs Services"
            sx={{ width: 120, height: 120, objectFit: 'contain', mb: 2 }}
          />
          <Typography variant="h4" component="h1" gutterBottom fontWeight="bold" color="primary">
            <TranslatedText text="Dada Cabs Services" />
          </Typography>
          <Typography variant="subtitle1" color="textSecondary">
            <TranslatedText text="Admin Panel Login" />
          </Typography>
        </Box>

        {error && (
          <Alert severity="error" sx={{ mb: 3 }}>
            {error}
          </Alert>
        )}

        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label={<TranslatedText text="Email Address" />}
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <EmailIcon color="action" />
                    </InputAdornment>
                  ),
                }}
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label={<TranslatedText text="Password" />}
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <LockIcon color="action" />
                    </InputAdornment>
                  ),
                  endAdornment: (
                    <InputAdornment position="end">
                      <IconButton onClick={() => setShowPassword(!showPassword)} edge="end">
                        {showPassword ? <VisibilityOffIcon /> : <VisibilityIcon />}
                      </IconButton>
                    </InputAdornment>
                  ),
                }}
              />
            </Grid>
            <Grid item xs={12}>
              <Button type="submit" fullWidth variant="contained" size="large" disabled={loading}>
                {loading ? <CircularProgress size={24} color="inherit" /> : <TranslatedText text="Sign In" />}
              </Button>
            </Grid>
          </Grid>
        </form>

        <Box sx={{ mt: 3, textAlign: 'center' }}>
          <Typography variant="body2" color="textSecondary">
            <TranslatedText text="Powered by Dada Cabs Services" />
          </Typography>
        </Box>
      </Paper>
    </Box>
  );
}

export default Login;