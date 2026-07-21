import React, { useEffect, useState } from 'react';
import api from '../services/api';
import { formatDate } from '../utils/dateFormat';
import {
  Box,
  Typography,
  Paper,
  IconButton,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Chip,
  TextField,
  MenuItem,
  Select,
  FormControl,
  InputLabel,
  Tooltip,
  Avatar,
} from '@mui/material';
import { DataGrid } from '@mui/x-data-grid';
import {
  Visibility as ViewIcon,
  Refresh as RefreshIcon,
  LocationOn as LocationIcon,
} from '@mui/icons-material';
import TranslatedText from '../components/TranslatedText';

function Trips() {
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedTrip, setSelectedTrip] = useState(null);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [statusFilter, setStatusFilter] = useState('all');
  const [paymentFilter, setPaymentFilter] = useState('all');
  const [transportTypeFilter, setTransportTypeFilter] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [statusOptions, setStatusOptions] = useState(['all']);

  const fetchTrips = async () => {
    try {
      setLoading(true);
      const allTrips = await api.trips.getAll();
      
      let filtered = allTrips;
      
      if (statusFilter !== 'all') {
        filtered = filtered.filter(t => t.status === statusFilter);
      }
      
      if (paymentFilter !== 'all') {
        filtered = filtered.filter(t => t.paymentStatus === paymentFilter);
      }
      
      if (transportTypeFilter !== 'all') {
        filtered = filtered.filter(t => {
          const tripTransportType = t.transportType || '';
          return tripTransportType.toLowerCase() === transportTypeFilter.toLowerCase();
        });
      }
      
      const tripsWithId = filtered.map(trip => ({
        ...trip,
        id: trip._id
      }));
      
      setTrips(tripsWithId);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching trips:', error);
      setLoading(false);
    }
  };

  const fetchStatusOptions = async () => {
    try {
      const data = await api.master.getByType('trip_status');
      const options = data.map(s => s.code);
      setStatusOptions(['all', ...options]);
    } catch (error) {
      console.error('Error fetching status options:', error);
      setStatusOptions(['all', 'pending', 'requested', 'accepted', 'ongoing', 'in_progress', 'arriving', 'arrived', 'completed', 'cancelled']);
    }
  };

  useEffect(() => {
    fetchTrips();
    fetchStatusOptions();
    const interval = setInterval(fetchTrips, 30000); // Poll every 30 seconds
    return () => clearInterval(interval);
  }, [statusFilter, paymentFilter, transportTypeFilter, fetchTrips]);

  const handleViewTrip = (trip) => {
    setSelectedTrip(trip);
    setViewDialogOpen(true);
  };

  const handleUpdateStatus = async (tripId, newStatus) => {
    try {
      await api.trips.update(tripId, { status: newStatus, updatedAt: new Date().toISOString() });
      fetchTrips();
    } catch (error) {
      console.error('Error updating trip status:', error);
      alert('Failed to update trip status');
    }
  };

  const getStatusColor = (status) => {
    const colors = {
      pending: 'warning',
      requested: 'warning',
      accepted: 'info',
      arriving: 'info',
      arrived: 'success',
      ongoing: 'primary',
      in_progress: 'primary',
      completed: 'success',
      cancelled: 'error',
    };
    return colors[status] || 'default';
  };

  const filteredTrips = trips.filter(trip =>
    trip.userId?.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    trip.driverId?.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    trip.pickupLocation?.address?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    trip._id?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const columns = [
    {
      field: '_id',
      headerName: 'Trip ID',
      width: 120,
      renderCell: (params) => (
        <Typography variant="body2" fontFamily="monospace">
          #{params.value?.slice(-6)}
        </Typography>
      ),
    },
    {
      field: 'createdAt',
      headerName: <TranslatedText text="Date" />,
      width: 180,
      renderCell: (params) => (
        <Typography variant="body2">
          {formatDate(params.value)}
        </Typography>
      ),
    },
    {
      field: 'userId.name',
      headerName: <TranslatedText text="Rider" />,
      width: 150,
      flex: 0.5,
      valueGetter: (params) => params.row.userId?.name || 'Unknown',
    },
    {
      field: 'driverId.name',
      headerName: <TranslatedText text="Driver" />,
      width: 150,
      flex: 0.5,
      valueGetter: (params) => params.row.driverName || params.row.driverId?.name || 'Unassigned',
    },
    {
      field: 'transportType',
      headerName: <TranslatedText text="Transport Type" />,
      width: 130,
      renderCell: (params) => (
        <Chip
          label={params.value || 'Car'}
          size="small"
          variant="outlined"
          color="primary"
        />
      ),
    },
    {
      field: 'pickupLocation.address',
      headerName: <TranslatedText text="Pickup" />,
      width: 200,
      flex: 1,
      valueGetter: (params) => params.row.pickupLocation?.address || 'Unknown',
      renderCell: (params) => (
        <Typography variant="body2" noWrap>
          {params.value?.substring(0, 40) || 'Unknown'}...
        </Typography>
      ),
    },
    {
      field: 'totalFare',
      headerName: <TranslatedText text="Fare (₹)" />,
      width: 100,
      renderCell: (params) => (
        <Typography variant="body2" fontWeight="medium">
          ₹{typeof params.value === 'number' ? params.value.toFixed(2) : '0.00'}
        </Typography>
      ),
    },
    {
      field: 'status',
      headerName: <TranslatedText text="Status" />,
      width: 120,
      renderCell: (params) => (
        <Chip
          label={params.value}
          color={getStatusColor(params.value)}
          size="small"
        />
      ),
    },
    {
      field: 'paymentStatus',
      headerName: <TranslatedText text="Payment" />,
      width: 100,
      renderCell: (params) => (
        <Chip
          label={params.value || 'pending'}
          color={params.value === 'paid' ? 'success' : 'warning'}
          size="small"
          variant="outlined"
        />
      ),
    },
    {
      field: 'actions',
      headerName: <TranslatedText text="Actions" />,
      width: 100,
      sortable: false,
      renderCell: (params) => (
        <Box>
          <Tooltip title={<TranslatedText text="View Details" />}>
            <IconButton onClick={() => handleViewTrip(params.row)} size="small">
              <ViewIcon />
            </IconButton>
          </Tooltip>
        </Box>
      ),
    },
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Typography variant="h4" fontWeight="bold">
          <TranslatedText text="Trip Management" />
        </Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel><TranslatedText text="Status Filter" /></InputLabel>
            <Select
              value={statusFilter}
              label={<TranslatedText text="Status Filter" />}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              {statusOptions.map(status => (
                <MenuItem key={status} value={status}>
                  {status.charAt(0).toUpperCase() + status.slice(1)}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel><TranslatedText text="Transport Type" /></InputLabel>
            <Select
              value={transportTypeFilter}
              label={<TranslatedText text="Transport Type" />}
              onChange={(e) => setTransportTypeFilter(e.target.value)}
            >
              <MenuItem value="all"><TranslatedText text="All" /></MenuItem>
              <MenuItem value="Auto">Auto</MenuItem>
              <MenuItem value="Car">Car</MenuItem>
              <MenuItem value="Bike">Bike</MenuItem>
              <MenuItem value="Suv">Suv</MenuItem>
              <MenuItem value="Van">Van</MenuItem>
            </Select>
          </FormControl>
          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel><TranslatedText text="Payment Filter" /></InputLabel>
            <Select
              value={paymentFilter}
              label={<TranslatedText text="Payment Filter" />}
              onChange={(e) => setPaymentFilter(e.target.value)}
            >
              <MenuItem value="all"><TranslatedText text="All" /></MenuItem>
              <MenuItem value="paid"><TranslatedText text="Paid" /></MenuItem>
              <MenuItem value="pending"><TranslatedText text="Pending" /></MenuItem>
              <MenuItem value="failed"><TranslatedText text="Failed" /></MenuItem>
            </Select>
          </FormControl>
          <TextField
            size="small"
            placeholder="Search trips..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            sx={{ width: 250 }}
          />
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={() => {
              setStatusFilter('all');
              setPaymentFilter('all');
              setTransportTypeFilter('all');
              setSearchTerm('');
            }}
          >
            <TranslatedText text="Reset" />
          </Button>
        </Box>
      </Box>

      <Paper sx={{ height: 'calc(100vh - 250px)' }}>
        <DataGrid
          rows={filteredTrips}
          columns={columns}
          pageSize={25}
          rowsPerPageOptions={[25, 50, 100]}
          loading={loading}
          checkboxSelection
          disableSelectionOnClick
          density="compact"
        />
      </Paper>

      {/* View Trip Dialog */}
      <Dialog open={viewDialogOpen} onClose={() => setViewDialogOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle><TranslatedText text="Trip Details" /> #{selectedTrip?._id?.slice(-6)}</DialogTitle>
        <DialogContent>
          {selectedTrip && (
            <Box sx={{ pt: 2 }}>
              <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 3 }}>
                {/* Rider Info */}
                <Paper sx={{ p: 2 }}>
                  <Typography variant="subtitle2" color="textSecondary" gutterBottom>
                    <TranslatedText text="Rider Information" />
                  </Typography>
                  <Typography variant="body1" fontWeight="medium">
                    {selectedTrip.userName || selectedTrip.userId?.name || 'Unknown'}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    {selectedTrip.userPhone || selectedTrip.userId?.phone || 'No phone'}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    {selectedTrip.userEmail || selectedTrip.userId?.email || 'No email'}
                  </Typography>
                </Paper>

                {/* Driver Info */}
                <Paper sx={{ p: 2 }}>
                  <Typography variant="subtitle2" color="textSecondary" gutterBottom>
                    <TranslatedText text="Driver Information" />
                  </Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                    {selectedTrip.driverId?.photo ? (
                      <Avatar
                        src={selectedTrip.driverId.photo}
                        alt={selectedTrip.driverId.name}
                        sx={{ width: 60, height: 60 }}
                      />
                    ) : (
                      <Avatar sx={{ width: 60, height: 60, bgcolor: 'primary.main' }}>
                        {selectedTrip.driverId?.name?.charAt(0) || '?'}
                      </Avatar>
                    )}
                    <Box>
                      <Typography variant="body1" fontWeight="medium">
                        {selectedTrip.driverId?.name || 'Unassigned'}
                      </Typography>
                      <Typography variant="body2" color="textSecondary">
                        {selectedTrip.driverId?.phone || 'No phone'}
                      </Typography>
                      {selectedTrip.driverId?.rating && (
                        <Typography variant="body2" color="textSecondary">
                          Rating: {selectedTrip.driverId.rating} ★
                        </Typography>
                      )}
                    </Box>
                  </Box>
                  {selectedTrip.driverId?.carName && (
                    <Typography variant="body2" color="textSecondary">
                      {selectedTrip.driverId.carName} • {selectedTrip.driverId.carPlateNum}
                    </Typography>
                  )}
                </Paper>

                {/* Route Info */}
                <Paper sx={{ p: 2, gridColumn: 'span 2' }}>
                  <Typography variant="subtitle2" color="textSecondary" gutterBottom>
                    <TranslatedText text="Route" />
                  </Typography>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
                    <LocationIcon color="success" />
                    <Typography variant="body1">
                      {selectedTrip.pickupLocation?.address || 'Unknown'}
                    </Typography>
                  </Box>
                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                    <LocationIcon color="error" />
                    <Typography variant="body1">
                      {selectedTrip.dropoffLocation?.address || 'Unknown'}
                    </Typography>
                  </Box>
                </Paper>

                {/* Trip Stats */}
                <Paper sx={{ p: 2 }}>
                  <Typography variant="subtitle2" color="textSecondary" gutterBottom>
                    <TranslatedText text="Trip Details" />
                  </Typography>
                  <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
                    <Box>
                      <Typography variant="caption" color="textSecondary"><TranslatedText text="Distance" /></Typography>
                      <Typography variant="body1" fontWeight="medium">
                        {typeof selectedTrip.distance === 'number' ? selectedTrip.distance.toFixed(2) : '0.00'} km
                      </Typography>
                    </Box>
                    <Box>
                      <Typography variant="caption" color="textSecondary"><TranslatedText text="Duration" /></Typography>
                      <Typography variant="body1" fontWeight="medium">
                        {selectedTrip.duration || 0} min
                      </Typography>
                    </Box>
                    <Box>
                      <Typography variant="caption" color="textSecondary"><TranslatedText text="Fare" /></Typography>
                      <Typography variant="body1" fontWeight="medium">
                        ₹{typeof selectedTrip.totalFare === 'number' ? selectedTrip.totalFare.toFixed(2) : '0.00'}
                      </Typography>
                    </Box>
                    <Box>
                      <Typography variant="caption" color="textSecondary"><TranslatedText text="Payment" /></Typography>
                      <Chip
                        label={selectedTrip.paymentMethod || 'Pending'}
                        size="small"
                        color={selectedTrip.paymentStatus === 'paid' ? 'success' : 'warning'}
                      />
                    </Box>
                  </Box>
                </Paper>

                {/* Status */}
                <Paper sx={{ p: 2 }}>
                  <Typography variant="subtitle2" color="textSecondary" gutterBottom>
                    <TranslatedText text="Current Status" />
                  </Typography>
                  <Chip
                    label={selectedTrip.status}
                    color={getStatusColor(selectedTrip.status)}
                    sx={{ mb: 2 }}
                  />
                  <Box>
                    <Typography variant="caption" color="textSecondary"><TranslatedText text="Created" /></Typography>
                    <Typography variant="body2">
                      {formatDate(selectedTrip.createdAt)}
                    </Typography>
                  </Box>
                </Paper>
              </Box>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setViewDialogOpen(false)}><TranslatedText text="Close" /></Button>
          {selectedTrip?.status === 'requested' && (
            <Button
              onClick={() => {
                handleUpdateStatus(selectedTrip._id, 'cancelled');
                setViewDialogOpen(false);
              }}
              color="error"
            >
              <TranslatedText text="Cancel Trip" />
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
}

export default Trips;