import React, { useState, useEffect } from 'react';
import api from '../../services/api';
import { formatDate } from '../../utils/dateFormat';
import TranslatedText from '../../components/TranslatedText';
import {
  Box,
  Typography,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Button,
  Chip,
  IconButton,
  Tooltip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  LinearProgress,
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  Visibility as ViewIcon,
  MyLocation as LocationIcon,
  Phone as PhoneIcon,
  Cancel as CancelIcon,
} from '@mui/icons-material';

function OngoingRides() {
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedTrip, setSelectedTrip] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);

  useEffect(() => {
    fetchOngoingTrips();
    const interval = setInterval(fetchOngoingTrips, 10000); // Poll every 10 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchOngoingTrips = async () => {
    try {
      setLoading(true);
      const data = await api.trips.getAll();
      const ongoingTrips = data.filter(trip => 
        ['in_progress', 'ongoing', 'accepted', 'started', 'arriving', 'arrived'].includes(trip.status)
      );
      setTrips(ongoingTrips);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching ongoing rides:', error);
      setLoading(false);
    }
  };

  const handleViewTrip = (trip) => {
    setSelectedTrip(trip);
    setDialogOpen(true);
  };

  const handleCancelTrip = async (trip) => {
    if (window.confirm(`Are you sure you want to cancel this trip?`)) {
      try {
        await api.trips.update(trip._id, { status: 'cancelled', cancellationReason: 'Admin cancelled' });
        setTrips(trips.filter(t => t._id !== trip._id));
      } catch (error) {
        console.error('Error cancelling trip:', error);
      }
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'accepted': return 'info';
      case 'arriving': return 'info';
      case 'started': return 'primary';
      case 'in_progress': return 'warning';
      case 'ongoing': return 'warning';
      case 'arrived': return 'success';
      default: return 'default';
    }
  };

  const calculateDuration = (startedAt) => {
    if (!startedAt) return '0 min';
    const start = new Date(startedAt);
    const now = new Date();
    const diff = Math.floor((now - start) / 60000); // Convert to minutes
    return `${diff} min`;
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" fontWeight="bold">
          Ongoing Rides
        </Typography>
        <Button
          variant="outlined"
          startIcon={<RefreshIcon />}
          onClick={fetchOngoingTrips}
        >
          Refresh
        </Button>
      </Box>

      {/* Summary Cards */}
      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 2, mb: 3 }}>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="Total Ongoing" /></Typography>
          <Typography variant="h3" fontWeight="bold">{trips.length}</Typography>
        </Paper>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="Accepted" /></Typography>
          <Typography variant="h3" fontWeight="bold" color="info.main">
            {trips.filter(t => t.status === 'accepted').length}
          </Typography>
        </Paper>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="In Progress" /></Typography>
          <Typography variant="h3" fontWeight="bold" color="warning.main">
            {trips.filter(t => t.status === 'in_progress').length}
          </Typography>
        </Paper>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="Started" /></Typography>
          <Typography variant="h3" fontWeight="bold" color="primary.main">
            {trips.filter(t => t.status === 'started').length}
          </Typography>
        </Paper>
      </Box>

      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Trip ID</TableCell>
                <TableCell>Rider</TableCell>
                <TableCell>Driver</TableCell>
                <TableCell>Pickup</TableCell>
                <TableCell>Dropoff</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Duration</TableCell>
                <TableCell>Fare</TableCell>
                <TableCell>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {trips.map((trip) => (
                <TableRow key={trip._id}>
                  <TableCell sx={{ fontFamily: 'monospace' }}>
                    #{trip._id?.slice(-6)}
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" fontWeight="bold">
                      {trip.userId?.name || 'Unknown'}
                    </Typography>
                    <Typography variant="caption" color="textSecondary">
                      {trip.userId?.phone || '-'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" fontWeight="bold">
                      {trip.driverId?.name || 'Unassigned'}
                    </Typography>
                    <Typography variant="caption" color="textSecondary">
                      {trip.driverId?.carPlateNum || '-'}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ maxWidth: 150 }}>
                    <Typography variant="body2" noWrap>
                      {trip.pickupLocation?.address || 'Unknown'}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ maxWidth: 150 }}>
                    <Typography variant="body2" noWrap>
                      {trip.dropoffLocation?.address || 'Unknown'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={trip.status}
                      color={getStatusColor(trip.status)}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>{calculateDuration(trip.startedAt)}</TableCell>
                  <TableCell>₹{trip.fare?.toFixed(2) || '0.00'}</TableCell>
                  <TableCell>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                      <Tooltip title={<TranslatedText text="View Details" />}>
                        <IconButton onClick={() => handleViewTrip(trip)} size="small">
                          <ViewIcon />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title={<TranslatedText text="Cancel Trip" />}>
                        <IconButton
                          onClick={() => handleCancelTrip(trip)}
                          size="small"
                          color="error"
                        >
                          <CancelIcon />
                        </IconButton>
                      </Tooltip>
                    </Box>
                  </TableCell>
                </TableRow>
              ))}
              {trips.length === 0 && (
                <TableRow>
                  <TableCell colSpan={9} align="center">
                    <Typography variant="body1" color="textSecondary" sx={{ py: 4 }}>
                      No ongoing rides
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Trip Details Dialog */}
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>Ride Details - #{selectedTrip?._id?.slice(-6)}</DialogTitle>
        <DialogContent>
          {selectedTrip && (
            <Box sx={{ pt: 2 }}>
              <Alert severity={getStatusColor(selectedTrip.status)} sx={{ mb: 2 }}>
                Status: {selectedTrip.status.toUpperCase()}
              </Alert>
              
              <Typography variant="h6" gutterBottom><TranslatedText text="Rider Information" /></Typography>
              <Table size="small">
                <TableBody>
                  <TableRow>
                    <TableCell><strong>Name:</strong></TableCell>
                    <TableCell>{selectedTrip.userId?.name || 'Unknown'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Phone:</strong></TableCell>
                    <TableCell>{selectedTrip.userId?.phone || '-'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Email:</strong></TableCell>
                    <TableCell>{selectedTrip.userId?.email || '-'}</TableCell>
                  </TableRow>
                </TableBody>
              </Table>

              <Typography variant="h6" gutterBottom sx={{ mt: 2 }}><TranslatedText text="Driver Information" /></Typography>
              <Table size="small">
                <TableBody>
                  <TableRow>
                    <TableCell><strong>Name:</strong></TableCell>
                    <TableCell>{selectedTrip.driverId?.name || 'Unassigned'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Phone:</strong></TableCell>
                    <TableCell>{selectedTrip.driverId?.phone || '-'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Vehicle:</strong></TableCell>
                    <TableCell>{selectedTrip.driverId?.carName || '-'} ({selectedTrip.driverId?.carPlateNum || '-'})</TableCell>
                  </TableRow>
                </TableBody>
              </Table>

              <Typography variant="h6" gutterBottom sx={{ mt: 2 }}><TranslatedText text="Route Information" /></Typography>
              <Table size="small">
                <TableBody>
                  <TableRow>
                    <TableCell><strong>Pickup:</strong></TableCell>
                    <TableCell>{selectedTrip.pickupLocation?.address || 'Unknown'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Dropoff:</strong></TableCell>
                    <TableCell>{selectedTrip.dropoffLocation?.address || 'Unknown'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Distance:</strong></TableCell>
                    <TableCell>{selectedTrip.distance} km</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Duration:</strong></TableCell>
                    <TableCell>{selectedTrip.duration} min</TableCell>
                  </TableRow>
                </TableBody>
              </Table>

              <Typography variant="h6" gutterBottom sx={{ mt: 2 }}><TranslatedText text="Trip Details" /></Typography>
              <Table size="small">
                <TableBody>
                  <TableRow>
                    <TableCell><strong>Vehicle Type:</strong></TableCell>
                    <TableCell>{selectedTrip.vehicleType}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Fare:</strong></TableCell>
                    <TableCell>₹{(selectedTrip.totalFare || selectedTrip.fare || 0).toFixed(2)}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Payment Method:</strong></TableCell>
                    <TableCell>{selectedTrip.paymentMethod || '-'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Requested At:</strong></TableCell>
                    <TableCell>{selectedTrip.requestedAt ? formatDate(selectedTrip.requestedAt) : '-'}</TableCell>
                  </TableRow>
                  {selectedTrip.startedAt && (
                    <TableRow>
                      <TableCell><strong>Started At:</strong></TableCell>
                      <TableCell>{formatDate(selectedTrip.startedAt)}</TableCell>
                    </TableRow>
                  )}
                  <TableRow>
                    <TableCell><strong>Duration:</strong></TableCell>
                    <TableCell>{calculateDuration(selectedTrip.startedAt)}</TableCell>
                  </TableRow>
                </TableBody>
              </Table>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}><TranslatedText text="Close" /></Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}

export default OngoingRides;
