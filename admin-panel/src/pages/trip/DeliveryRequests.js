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
  Select,
  MenuItem,
  FormControl,
  InputLabel,
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  Visibility as ViewIcon,
  LocalShipping as DeliveryIcon,
  CheckCircle as AcceptIcon,
  Cancel as RejectIcon,
} from '@mui/icons-material';

function DeliveryRequests() {
  const [deliveries, setDeliveries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedDelivery, setSelectedDelivery] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [filterStatus, setFilterStatus] = useState('all');
  const [tripStatuses, setTripStatuses] = useState([]);

  useEffect(() => {
    fetchDeliveries();
    fetchMasterData();
    const interval = setInterval(fetchDeliveries, 15000); // Poll every 15 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchMasterData = async () => {
    try {
      const statuses = await api.master.getByType('trip_status');
      setTripStatuses(statuses || []);
    } catch (error) {
      console.error('Error fetching master data:', error);
    }
  };

  const fetchDeliveries = async () => {
    try {
      console.log('Fetching delivery requests...');
      setLoading(true);
      const data = await api.trips.getAll();
      console.log('All trips data:', data);
      // Filter trips that might be deliveries (handle both Admin and Customer naming)
      const deliveryTrips = data.filter(trip => {
        const svc = (trip.serviceType || '').toLowerCase();
        const vt = (trip.vehicleType || trip.transportType || trip.carType || '').toLowerCase();
        return svc.startsWith('parcel') || svc === 'delivery'
          || vt.includes('truck') || vt.includes('delivery') || vt.includes('cargo')
          || trip.vehicleType === 'delivery' || trip.vehicleType === 'truck' || trip.vehicleType === 'cargo';
      });
      console.log('Filtered delivery trips:', deliveryTrips);
      setDeliveries(deliveryTrips);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching delivery requests:', error);
      setLoading(false);
    }
  };

  const handleViewDelivery = (delivery) => {
    setSelectedDelivery(delivery);
    setDialogOpen(true);
  };

  const handleAcceptDelivery = async (delivery) => {
    try {
      await api.trips.update(delivery._id, { status: 'accepted' });
      setDeliveries(deliveries.map(d => 
        d._id === delivery._id ? { ...d, status: 'accepted' } : d
      ));
    } catch (error) {
      console.error('Error accepting delivery:', error);
    }
  };

  const handleRejectDelivery = async (delivery) => {
    if (window.confirm('Are you sure you want to reject this delivery request?')) {
      try {
        await api.trips.update(delivery._id, { status: 'cancelled', cancellationReason: 'Rejected by admin' });
        setDeliveries(deliveries.filter(d => d._id !== delivery._id));
      } catch (error) {
        console.error('Error rejecting delivery:', error);
      }
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'requested': return 'warning';
      case 'accepted': return 'info';
      case 'in_progress': return 'primary';
      case 'completed': return 'success';
      case 'cancelled': return 'error';
      default: return 'default';
    }
  };

  const filteredDeliveries = filterStatus === 'all' 
    ? deliveries 
    : deliveries.filter(d => d.status === filterStatus);

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" fontWeight="bold">
          Delivery Requests
        </Typography>
        <Box sx={{ display: 'flex', gap: 2, alignItems: 'center' }}>
          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel>Status</InputLabel>
            <Select
              value={filterStatus}
              label={<TranslatedText text="Status" />}
              onChange={(e) => setFilterStatus(e.target.value)}
            >
              <MenuItem value="all"><TranslatedText text="All Status" /></MenuItem>
              {tripStatuses.map((status) => (
                <MenuItem key={status.code} value={status.code}>
                  {status.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={fetchDeliveries}
          >
            Refresh
          </Button>
        </Box>
      </Box>

      {/* Summary Cards */}
      <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 2, mb: 3 }}>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="Total Deliveries" /></Typography>
          <Typography variant="h3" fontWeight="bold">{deliveries.length}</Typography>
        </Paper>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="Pending" /></Typography>
          <Typography variant="h3" fontWeight="bold" color="warning.main">
            {deliveries.filter(d => d.status === 'requested').length}
          </Typography>
        </Paper>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="In Progress" /></Typography>
          <Typography variant="h3" fontWeight="bold" color="primary.main">
            {deliveries.filter(d => d.status === 'in_progress').length}
          </Typography>
        </Paper>
        <Paper sx={{ p: 3, textAlign: 'center' }}>
          <Typography variant="h6" color="textSecondary"><TranslatedText text="Completed" /></Typography>
          <Typography variant="h3" fontWeight="bold" color="success.main">
            {deliveries.filter(d => d.status === 'completed').length}
          </Typography>
        </Paper>
      </Box>

      <Paper>
        <TableContainer>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Delivery ID</TableCell>
                <TableCell>Customer</TableCell>
                <TableCell>Pickup Location</TableCell>
                <TableCell>Dropoff Location</TableCell>
                <TableCell>Distance</TableCell>
                <TableCell>Fare</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredDeliveries.map((delivery) => (
                <TableRow key={delivery._id}>
                  <TableCell sx={{ fontFamily: 'monospace' }}>
                    #{delivery._id?.slice(-6)}
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" fontWeight="bold">
                      {delivery.userId?.name || 'Unknown'}
                    </Typography>
                    <Typography variant="caption" color="textSecondary">
                      {delivery.userId?.phone || '-'}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ maxWidth: 150 }}>
                    <Typography variant="body2" noWrap>
                      {delivery.pickupLocation?.address || 'Unknown'}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ maxWidth: 150 }}>
                    <Typography variant="body2" noWrap>
                      {delivery.dropoffLocation?.address || 'Unknown'}
                    </Typography>
                  </TableCell>
                  <TableCell>{delivery.distance} km</TableCell>
                  <TableCell>₹{delivery.fare?.toFixed(2) || '0.00'}</TableCell>
                  <TableCell>
                    <Chip
                      label={delivery.status}
                      color={getStatusColor(delivery.status)}
                      size="small"
                    />
                  </TableCell>
                  <TableCell>
                    <Box sx={{ display: 'flex', gap: 1 }}>
                      <Tooltip title={<TranslatedText text="View Details" />}>
                        <IconButton onClick={() => handleViewDelivery(delivery)} size="small">
                          <ViewIcon />
                        </IconButton>
                      </Tooltip>
                      {delivery.status === 'requested' && (
                        <>
                          <Tooltip title={<TranslatedText text="Accept" />}>
                            <IconButton
                              onClick={() => handleAcceptDelivery(delivery)}
                              size="small"
                              color="success"
                            >
                              <AcceptIcon />
                            </IconButton>
                          </Tooltip>
                          <Tooltip title={<TranslatedText text="Reject" />}>
                            <IconButton
                              onClick={() => handleRejectDelivery(delivery)}
                              size="small"
                              color="error"
                            >
                              <RejectIcon />
                            </IconButton>
                          </Tooltip>
                        </>
                      )}
                    </Box>
                  </TableCell>
                </TableRow>
              ))}
              {filteredDeliveries.length === 0 && (
                <TableRow>
                  <TableCell colSpan={8} align="center">
                    <Typography variant="body1" color="textSecondary" sx={{ py: 4 }}>
                      No delivery requests found
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      {/* Delivery Details Dialog */}
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>Delivery Details - #{selectedDelivery?._id?.slice(-6)}</DialogTitle>
        <DialogContent>
          {selectedDelivery && (
            <Box sx={{ pt: 2 }}>
              <Alert severity={getStatusColor(selectedDelivery.status)} sx={{ mb: 2 }}>
                Status: {selectedDelivery.status.toUpperCase()}
              </Alert>
              
              <Typography variant="h6" gutterBottom><TranslatedText text="Customer Information" /></Typography>
              <Table size="small">
                <TableBody>
                  <TableRow>
                    <TableCell><strong>Name:</strong></TableCell>
                    <TableCell>{selectedDelivery.userId?.name || 'Unknown'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Phone:</strong></TableCell>
                    <TableCell>{selectedDelivery.userId?.phone || '-'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Email:</strong></TableCell>
                    <TableCell>{selectedDelivery.userId?.email || '-'}</TableCell>
                  </TableRow>
                </TableBody>
              </Table>

              <Typography variant="h6" gutterBottom sx={{ mt: 2 }}><TranslatedText text="Delivery Route" /></Typography>
              <Table size="small">
                <TableBody>
                  <TableRow>
                    <TableCell><strong>Pickup:</strong></TableCell>
                    <TableCell>{selectedDelivery.pickupLocation?.address || 'Unknown'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Pickup Landmark:</strong></TableCell>
                    <TableCell>{selectedDelivery.pickupLocation?.landmark || '-'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Dropoff:</strong></TableCell>
                    <TableCell>{selectedDelivery.dropoffLocation?.address || 'Unknown'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Dropoff Landmark:</strong></TableCell>
                    <TableCell>{selectedDelivery.dropoffLocation?.landmark || '-'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Distance:</strong></TableCell>
                    <TableCell>{selectedDelivery.distance} km</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Estimated Duration:</strong></TableCell>
                    <TableCell>{selectedDelivery.duration} min</TableCell>
                  </TableRow>
                </TableBody>
              </Table>

              <Typography variant="h6" gutterBottom sx={{ mt: 2 }}><TranslatedText text="Delivery Details" /></Typography>
              <Table size="small">
                <TableBody>
                  <TableRow>
                    <TableCell><strong>Vehicle Type:</strong></TableCell>
                    <TableCell>{selectedDelivery.vehicleType}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Fare:</strong></TableCell>
                    <TableCell>₹{selectedDelivery.fare?.toFixed(2) || '0.00'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Payment Method:</strong></TableCell>
                    <TableCell>{selectedDelivery.paymentMethod || '-'}</TableCell>
                  </TableRow>
                  <TableRow>
                    <TableCell><strong>Requested At:</strong></TableCell>
                    <TableCell>{selectedDelivery.requestedAt ? formatDate(selectedDelivery.requestedAt) : '-'}</TableCell>
                  </TableRow>
                  {selectedDelivery.acceptedAt && (
                    <TableRow>
                      <TableCell><strong>Accepted At:</strong></TableCell>
                      <TableCell>{formatDate(selectedDelivery.acceptedAt)}</TableCell>
                    </TableRow>
                  )}
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

export default DeliveryRequests;
